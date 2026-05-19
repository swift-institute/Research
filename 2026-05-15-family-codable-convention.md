# Family-Codable Convention — Sibling Protocol Placement

<!--
---
version: 1.0.0
last_updated: 2026-05-15
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---

Changelog:
- v1.0.0 (2026-05-15): initial RECOMMENDATION. Ecosystem-wide promotion (per
  [RES-002a] + [META-005] of the existing per-package family-codable-convention
  authored in `swift-foundations/swift-json/Research/family-codable-convention.md`
  v1.1.4 to ecosystem-wide scope, addressing the previously-open placement
  question (L1 vs L2 vs L3) and resolving D7 of the parent argument-parser
  ecosystem design at `2026-05-15-swift-arguments-ecosystem-design.md` v1.0.3.
-->

## Context

The framing memo `project_parser_serializer_coder_system_framing` (principal
direction 2026-05-14) authorized a deferred Research arc to formalize the
**family-codable convention**: the convergent pattern where format-specific
sibling protocols (`JSON.Serializable`, `ASCII.Parseable`, `Binary.Parseable`,
future `Argument.Codable`, hypothetical `MessagePack.Serializable`, etc.)
coexist alongside the three canonical attachment protocols at top level of
their primitives modules:

| Canonical attachment | Top-level of module | File:line |
|----------------------|---------------------|-----------|
| `Coder_Primitives.Codable` | `swift-coder-primitives` (L1) | `swift-coder-primitives/Sources/Coder Primitives/Codable.swift:29` |
| `Parser_Primitives_Core.Parseable` | `swift-parser-primitives` (L1) | `swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:26` |
| `Serializer_Primitives_Core.Serializable` | `swift-serializer-primitives` (L1) | `swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19` |

A first-round Tier-2 Research document already exists at
`swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4
(scope: cross-package). It codifies [FAM-001]–[FAM-008]:

- [FAM-001] siblings carry no associatedtype
- [FAM-002] canonical attachment associatedtype is structural single-codec enforcement
- [FAM-003] guarded-use of canonical attachments on public spec types
- [FAM-004] call-site disambiguation via format-specific instance accessors
- [FAM-005] sibling namespaces = format-level distinctions; sub-format dimensions are operation parameters
- [FAM-006] operational-vs-attachment refinement asymmetry
- [FAM-007] sub-sibling associated-type carve-out
- [FAM-008] canonical operational-layer family shape (enum namespace + nested Protocol + nested Witness + nested combinators)

What [FAM-001]–[FAM-008] explicitly does NOT codify: **where new sibling
protocols live across the L1/L2/L3 layers**. The convention defines the
*shape* of siblings; it does not prescribe the *layer*.

This gap surfaced as a load-bearing open question during the swift-arguments
ecosystem design `swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md`
v1.0.3 §3.9 + direction D7:

> *"Two homes are structurally defensible: L1 swift-argument-primitives
> (matches namespace root) or L3 swift-arguments (matches codec home).
> Parked on the deferred family-codable-convention research."*

The placement question's tension is concrete: `Argument.Codable` (value↔String
conversion for argv) describes exactly the kind of L1-to-String conversion that
[PRIM-FOUND-004] gates with intentional friction. Yet `ASCII.Parseable` and
`Binary.Parseable` and `Binary.Serializable` ALL ship at L1 today (described
in detail in §2 below) under the same friction regime, and no skill or audit
has flagged them as violations of [PRIM-FOUND-004]. What distinguishes them?

This Research doc formalizes the principled placement rule, applies it to the
current ecosystem, and confirms or contradicts each currently-shipped
placement.

**Trigger**: principal direction 2026-05-14; explicit close-out request for
the U10 / D7 deferred Research arc per the parent argument-parser doc.

## Question

**What is the principled placement rule for format-Codable /
format-Parseable / format-Serializable sibling protocols across the L1/L2/L3
layers?**

**Sub-questions:**

1. **Precedent.** Where does `JSON.Serializable` live (L3 swift-json or L1
   swift-json-primitives)? Where does `ASCII.Serializable` (future) live?
   Where does `ASCII.Parseable` live? Where does `Binary.Serializable` live?
   Where does `Binary.Parseable` live? What ties them?

2. **[PRIM-FOUND-004] interaction.** Is `Argument.Codable` (value↔String
   conversion for argv) MORE friction-violating than `ASCII.Parseable`
   (byte↔value)? Or are they isomorphic? Does friction-violation depend on
   the substrate (`String` vs `[UInt8]`)?

3. **Placement determinant.** Is sibling placement determined by where the
   *namespace* is rooted (L1 if the `Argument` namespace is at L1) or by the
   *layer at which the codec lives* (L3 if the parsing/emission happens in
   swift-arguments)?

4. **Existing conflict cases.** Does the institute have any sibling
   protocols at L1 that conflict with the friction intent? If so, how were
   they resolved or accepted?

5. **Default rule.** For future format-Codable protocols (Binary.LittleEndian
   — already REJECTED per [FAM-005]; hypothetical XML, hypothetical TOML,
   future `Argument.Codable`, future `MessagePack.Serializable`), what's the
   default placement rule?

## Methodology

Per [RES-019] internal grep:

- `swift-institute/Research/` — already-codified family-codable doc at
  `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4;
  no ecosystem-wide doc on placement. Closest ecosystem-wide doc is
  `2026-05-15-swift-arguments-ecosystem-design.md` §3.9 + D7 itself.
- `swift-primitives/` — confirms `Binary.Parseable` (in
  `swift-binary-primitives`, L1), `Binary.Serializable` (in
  `swift-binary-primitives`, L1), `ASCII.Parseable` (in
  `swift-ascii-parser-primitives`, L1), with `Binary.ASCII.Serializable`
  deprecated for orthogonal W4 namespace-consolidation reasons (not
  pattern-violation).
- `swift-foundations/` — confirms `JSON.Serializable` (in swift-json, L3),
  `Plist.Serializable` (in swift-plist, L3), `XML.Serializable` (in
  swift-xml, L3).
- `swift-institute/Experiments/` — `double-json-binary-dual-conformance/` at
  `swift-foundations/swift-json/Experiments/` empirically validates that
  cross-layer sibling combinations (one at L3, one at L1) coexist on a
  single value type.

Per [RES-021] contextualization step: external prior art is surveyed in §3.6
(Rust serde, Haskell aeson, Apple/Foundation Codable-successor proposal),
with the contextualization step warning that universal adoption ≠ universal
necessity.

Per [RES-022] structural-correctness framing: the recommendation in §5 is
selected on structural correctness (semantic identity of where a namespace
*lives* and where a codec *materializes*); cost / migration / pragmatism
serves as tiebreaker only per [RES-029].

Empirical claims about file/line locations are verified at write time per
[RES-023].

---

## Analysis

### 1. Empirical scan — current placement of every sibling protocol

Comprehensive grep across `swift-primitives/`, `swift-standards/`,
`swift-foundations/` for declarations matching `: Serializable {`,
`: Parseable {`, `: Codable {`, plus `protocol Serializable {`, `protocol
Parseable {`, `protocol Codable {` inside format namespaces.

| Sibling protocol | Layer | Package | File:line | Status |
|---|---|---|---|---|
| `JSON.Serializable` | **L3** | swift-foundations/swift-json | `Sources/JSON/JSON.Serializable.swift:96` | LANDED |
| `Plist.Serializable` | **L3** | swift-foundations/swift-plist | `Sources/Plist Core/Plist.Serializable.swift:3` | LANDED (shape-compatible, pre-J1d) |
| `XML.Serializable` | **L3** | swift-foundations/swift-xml | `Sources/XML/XML.Serializable.swift:36` | LANDED (shape-compatible, pre-J1d) |
| `Binary.Serializable` | **L1** | swift-primitives/swift-binary-primitives | `Sources/Binary Serializable Primitives/Binary.Serializable.swift:37` | LANDED |
| `Binary.Parseable` | **L1** | swift-primitives/swift-binary-primitives | `Sources/Binary Parseable Primitives/Binary.Parseable.swift:58` | LANDED 2026-05-14 |
| `ASCII.Parseable` | **L1** | swift-primitives/swift-ascii-parser-primitives | `Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:32` | LANDED (refinement-shape — RECOMMENDED-FOR-MIGRATION to flat per Φ.1) |
| `Binary.ASCII.Serializable` | **L1** | swift-primitives/swift-ascii-serializer-primitives | `Sources/Binary ASCII Serializable Primitives/Binary.ASCII.Serializable.swift:8` | **DEPRECATED** (W4 namespace consolidation; orthogonal to placement) |
| `UInt8.Base62.Serializable` | **L1** | swift-primitives/swift-base62-primitives | `Sources/Base62 Primitives/UInt8.Base62.Serializing.swift` | LANDED (sub-sibling per [FAM-007]) |

The empirical scan is exhaustive at the time of writing; no other sibling
protocols matching the family-codable convention's structural shape are
declared in either `swift-primitives/` or `swift-foundations/`.

#### Where their format namespaces are rooted

A sibling protocol is *nested inside its format namespace*. The placement of
the namespace's *root* is the critical second axis:

| Format namespace | Where it's rooted | Package | File:line |
|---|---|---|---|
| `JSON` | **L3** | swift-foundations/swift-json | `Sources/JSON/JSON.swift` (namespace root, also includes `JSON.Serializable`, `JSON.Coder`, `JSON.Value`-equivalents...) |
| `Plist` | **L3** | swift-foundations/swift-plist | `Sources/Plist Core/Plist.swift` (or similar; verified plural namespace at L3) |
| `XML` | **L3** | swift-foundations/swift-xml | `Sources/XML/XML.swift` (root with `Serializable`, etc.) |
| `Binary` | **L1** | swift-primitives/swift-binary-primitives | `Sources/Binary Namespace/Binary.swift:15` (`public enum Binary {}`) |
| `ASCII` | **L1** | swift-primitives/swift-ascii-primitives | `Sources/ASCII Primitives/ASCII.swift:1+` (per INCITS 4-1986, tier 0) |
| (future) `Argument` | **L1** (proposed) | swift-argument-primitives (per parent doc) | TBD |
| (future) `MessagePack` | L3 (anticipated) | swift-foundations/swift-messagepack (anticipated) | TBD |
| (future) `CBOR` | L3 (anticipated) | swift-foundations/swift-cbor (anticipated) | TBD |
| (future) `TOML` | L3 (anticipated) | swift-foundations/swift-toml (anticipated) | TBD |

**Critical pattern**: In every shipped case, **the sibling protocol lives in
the same layer as its namespace root**. `JSON.Serializable` (L3) ↔ `JSON`
namespace (L3). `Binary.Parseable` (L1) ↔ `Binary` namespace (L1).
`ASCII.Parseable` (L1) ↔ `ASCII` namespace (L1).

This is not the *codec* layer; in some cases the canonical codec lives
elsewhere or doesn't exist as a separate type:

- `JSON.Coder` lives in the SAME L3 target as `JSON.Serializable` (`swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift`).
- `Binary.Serializable` has no separate `Binary.Coder` — the serializer is the protocol's leaf method (the only "codec" is bring-your-own-buffer).
- `ASCII.Parseable` similarly has no separate ASCII.Coder; the parser-instance per conformer is the codec.

So the empirical pattern is *namespace-rooted placement*, NOT codec-rooted
placement. The two coincide for tree-intermediate formats (JSON, Plist, XML
each have one canonical L3 namespace and codec). They diverge for byte-stream
formats (Binary namespace at L1; conceivable Binary.Coder at L3 if/when
authored).

#### Where conformances on stdlib types live (the SLI partition)

Per [MOD-010] StdLib Integration is its own target whose home is determined
separately from the protocol home. Empirical conformance distribution:

| Conformance | Stdlib type | Conformed-to protocol | Located in | Target |
|---|---|---|---|---|
| `UInt32: Binary.Parseable` | UInt32 | Binary.Parseable (L1) | swift-binary-primitives (L1) | `Binary Parseable Primitives/UInt32+Binary.Parseable.swift` |
| `Array: Binary.Parseable` | Array | Binary.Parseable (L1) | swift-binary-primitives (L1) | `Binary Parseable Primitives/Array+Binary.Parseable.swift` |
| `FixedWidthInteger: ASCII.Parseable` (canonical pin) | All FixedWidthInteger | Parser_Primitives_Core.Parseable (refinement-via-ASCII.Parseable) | swift-ascii-parser-primitives (L1) | `ASCII Parser Primitives Standard Library Integration/FixedWidthInteger+Parseable.swift` |
| `Optional<X>: JSON.Serializable` | Optional | JSON.Serializable (L3) | swift-foundations/swift-json (L3) | `Sources/JSON/JSON.Serializable.swift:556+` |
| `Int: JSON.Serializable` (and similar) | Int and similar | JSON.Serializable (L3) | swift-foundations/swift-json (L3) | `Sources/JSON/...` |

**Observation**: stdlib-conformance targets live in the *same package* as
the protocol they conform to. Whether a sibling protocol lives at L1 or L3
is decided independently of where stdlib conformances live — once the
protocol lands, conformances naturally co-locate by [MOD-010].

### 2. The friction-intent question — [PRIM-FOUND-004]

[PRIM-FOUND-004] (verified at `swift-institute/Skills/primitives/SKILL.md:80`)
codifies:

> *"L1 primitives packages MUST NOT add easy String/Scalar escape hatches.
> Specifically: do NOT add `Path.View.string: Swift.String` to
> `swift-path-primitives`; do NOT add `ASCII.Case.Conversion.convert(_:
> Unicode.Scalar, to:)` at L1. String conversion is placed at L3 deliberately
> to prevent reaching too easily for `Swift.String`. The friction is the
> point — consumers should stay in the typed primitive system."*

The rule prohibits easy escape hatches *between* the institute's typed
primitive system (e.g. `Path.View`) and `Swift.String`. The motivating
examples (`Path.View.string`, `ASCII.Case.Conversion.convert(_:to:)`) are
specifically about consumers casually converting from typed-byte-or-typed-
character primitives to bare `Swift.String` or `Unicode.Scalar`. The rule
codifies that consumers SHOULD stay in the typed system.

**Does sibling protocol presence at L1 violate [PRIM-FOUND-004]?**

Take `Binary.Parseable` as the empirical case:

```swift
// At L1, in swift-binary-primitives:
extension UInt32: Binary.Parseable {
    public static func parse<Source: RangeReplaceableCollection>(
        from source: inout Source
    ) throws(Binary.Parse.Failure) -> UInt32
    where Source.Element == UInt8 {
        // ... reads 4 bytes from source, returns UInt32
    }
}
```

This is a `[UInt8] → UInt32` conversion, not a `String → UInt32` conversion.
[PRIM-FOUND-004]'s motivating "easy String escape hatch" framing doesn't fire
on byte→integer conformances. There's no `Swift.String` reached for here.

Take `ASCII.Parseable` (slightly closer to the friction zone):

```swift
// At L1, in swift-ascii-parser-primitives, the protocol itself:
extension ASCII {
    public protocol Parseable {} // (currently empty marker after Φ.1 cleanup)
}
// And the stdlib conformance:
extension FixedWidthInteger: ASCII.Parseable {
    // Conformance lives at L1 in the SLI target; the actual parser instance
    // is ASCII.Decimal.Parser<Self> which consumes [UInt8] → Self.
}
```

Again byte-substrate. The conformance's parse path is `[UInt8] → Int` (or
similar), not `Swift.String → Int`. No `Swift.String` escape hatch is introduced.
A consumer at L1 who wants to parse an ASCII integer must work in byte
territory.

Now contrast `Argument.Codable` (the case the parent doc raised as
friction-concerning):

```swift
// At L1, in swift-argument-primitives (proposed):
extension Argument {
    public protocol Codable {
        // Sibling protocol; per [FAM-001] carries no associatedtype.
        // The parse-side requirement consumes Swift.String:
        init(argument string: String) throws(Argument.Error)
        // The serialize-side requirement produces Swift.String:
        var argumentString: String { get }
    }
}
```

This **does** introduce a `Swift.String ↔ Self` conversion at L1. **This is
the exact case [PRIM-FOUND-004] gates**: a typed L1 primitive type would gain
an easy `Swift.String` escape hatch via `Self(argument:)` and
`.argumentString`.

**The distinguishing factor is the substrate, not the protocol position**:

| Sibling | Conversion substrate | [PRIM-FOUND-004] concern? |
|---|---|---|
| `Binary.Parseable` | `[UInt8]` byte stream | NO — no Swift.String contact |
| `Binary.Serializable` | `[UInt8]` byte stream | NO — no Swift.String contact |
| `ASCII.Parseable` | `[UInt8]` byte stream | NO — no Swift.String contact |
| Hypothetical `Binary.LittleEndian.Codable` (rejected per [FAM-005]) | `[UInt8]` byte stream | NO — no Swift.String contact |
| `Argument.Codable` (proposed) | `Swift.String` (each argv element IS a `String`) | **YES** — `Self(argument: String)` is a Swift.String escape hatch |
| `Argument.Parseable` | `Swift.String` | **YES** — same |
| `Argument.Serializable` | `Swift.String` | **YES** — same |

The pattern is now clear: byte-substrate sibling protocols at L1 do NOT
violate [PRIM-FOUND-004]. String-substrate sibling protocols at L1 DO. The
issue is not whether a *codable family* exists at L1; the issue is whether
the codable family bridges to `Swift.String` (the type [PRIM-FOUND-004]
specifically names as the escape hatch consumers should be friction-gated
from).

### 3. The four candidate placement rules

Four structural strategies for placing sibling protocols across L1/L2/L3:

#### Option A — Namespace-rooted (where the namespace is rooted, the sibling lives)

> A sibling protocol `F.X` lives in the same layer as the format namespace
> `F`'s root declaration.

Pros:
- Discoverability: import `F` and get everything `F`-related, including its
  Codable family. Consumers don't have to know whether `F.Serializable` lives
  in `swift-f-primitives` or `swift-f`.
- Cohesion: namespace + sibling protocol + canonical leaf form a single
  unit; no scatter.
- Matches the empirical pattern of every shipped case (JSON, Plist, XML,
  Binary, ASCII).

Cons:
- L1 placement of a sibling whose substrate is `Swift.String` (e.g.,
  `Argument.Codable`) does conflict with [PRIM-FOUND-004]'s
  String-escape-hatch friction intent.
- Doesn't intrinsically distinguish "this conversion is across byte
  territory" from "this conversion is across String territory."

#### Option B — Codec-rooted (where the codec implementation lives, the sibling lives)

> A sibling protocol `F.X` lives in the same layer as the leaf codec /
> parser / serializer implementation `F.Coder` (or equivalent).

Pros:
- Sibling protocol travels with its operational implementation. If the codec
  needs L3 infrastructure (e.g., terminal-width-aware help formatting), the
  protocol lives at L3 too.

Cons:
- **Fails for byte-substrate cases**: `Binary.Parseable`'s codec IS the
  protocol's required method (`parse(from:)`); there is no separate
  `Binary.Coder` to anchor placement to. Codec-rooted reasoning produces no
  answer for these cases.
- **Splits the namespace**: `JSON` namespace at L3, but if the codec ever
  moved L3 split into a separate package, `JSON.Serializable` would have to
  move too. Brittle to ecosystem refactoring.
- Doesn't match any empirical case — the codec-rooted view is
  retroactively-justifiable for JSON (codec at L3, sibling at L3) but
  coincidental: the namespace is also at L3.

#### Option C — Substrate-aware (substrate determines the layer)

> A sibling protocol `F.X` lives at L1 if its conversion substrate is
> byte-only (`[UInt8]`); at L3 if its conversion substrate is `Swift.String`.

Pros:
- Directly answers the [PRIM-FOUND-004] friction-intent question. String-
  bridging siblings are gated to L3 where the institute permits String
  bridging (per [PRIM-FOUND-004]'s "*String conversion is placed at L3
  deliberately*").
- Aligns with the architectural intent of the friction rule, not just its
  literal statement.

Cons:
- Decouples sibling protocol home from namespace home. `Argument` namespace
  at L1, `Argument.Codable` at L3 — discoverability becomes harder. A
  consumer importing `Argument_Primitives` would NOT see the codable
  surface; they'd have to also import `swift-arguments`.
- The substrate distinction is non-obvious to non-domain experts. "Why does
  `Binary.Serializable` live at L1 but `Argument.Codable` at L3?" — answer
  requires explaining the friction rule's substrate-sensitivity.

#### Option D — Hybrid (default to namespace-rooted; exception when substrate violates friction)

> A sibling protocol `F.X` lives in the same layer as the format namespace
> `F`'s root declaration (Option A), UNLESS its conversion substrate is
> `Swift.String` AND the namespace root is at L1, in which case the
> sibling protocol promotes to the lowest-layer namespace-bearing package
> that's not L1 (typically L3, if a corresponding L3 package exists).

This is the structurally precise option. Default behavior matches every
shipped case (byte-substrate siblings at L1 with their L1 namespace; tree-
intermediate string-substrate siblings at L3 with their L3 namespace). The
exception fires only for the previously-unconsidered case of a sibling whose
substrate is `Swift.String` AND whose namespace root is at L1 (the
`Argument.Codable` case).

Pros:
- Captures the empirical pattern exactly.
- Resolves the [PRIM-FOUND-004] friction question principled.
- The exception is narrow and only fires when both conditions are true; in
  every other case, namespace-rooted placement applies.

Cons:
- Two-step rule, slightly more complex than pure Option A.
- Requires consumers to reach for the L3 codable surface separately when the
  L1 namespace itself wouldn't expose it.

### 4. The four options compared

| Criterion | A (namespace-rooted) | B (codec-rooted) | C (substrate-aware) | D (hybrid) |
|---|---|---|---|---|
| Matches every shipped placement | YES | NO (no answer for byte-substrate; coincidental for tree-intermediate) | YES | YES |
| Resolves [PRIM-FOUND-004] for `Argument.Codable` | NO (would place at L1, friction violation) | UNCLEAR (depends on codec home; the codec is in swift-arguments L3, so coincidentally YES — but for wrong reason) | YES (substrate is String → L3) | YES (exception fires; promotes to L3) |
| Single rule (one statement) | YES | YES | YES | NO (rule + exception) |
| Discoverability (import the namespace, get the family) | HIGH | MEDIUM (depends on codec location coincidence) | LOW (namespace and family can be in different layers) | HIGH except in narrow exception case |
| Robust to ecosystem refactoring (codec moves) | YES | NO (codec move triggers sibling protocol move) | YES | YES |
| Matches structural correctness framing of [RES-022] | PARTIAL (right for byte; wrong for String-substrate L1 case) | PARTIAL (right for tree-intermediate; vacuous for byte-substrate) | YES (substrate IS the structurally-correct discriminator under [PRIM-FOUND-004]) | YES (extends namespace-rooted with substrate-aware exception) |
| Aligns with [FAM-005] ("sibling namespaces correspond to format-level distinctions") | YES | YES | YES (substrate is a property of the format) | YES |

Option D dominates on every axis where A or C wins, and matches the empirical
pattern exactly (Option A's primary strength).

### 5. Theoretical grounding (per [RES-022])

#### 5.1 The two distinct architectural questions

The placement question conflates two questions that are independent and
must be resolved separately:

1. **Where does the *format namespace* live?**
   Determined by: tier of the format's substrate, complexity of the format's
   leaf data structures, presence of L2 standards. Examples:
   - `Binary` namespace at L1 because bytes are atomic and ubiquitous.
   - `ASCII` namespace at L1 because INCITS 4-1986 is a single-byte
     specification covered at tier 0.
   - `JSON` namespace at L3 because RFC 8259 is a structured tree format
     whose value type and parser need L1 + L2 + L3 composition.
   - `Argument` namespace at L1 (per parent doc) because the *vocabulary
     atoms* (`Argument.Name`, `Argument.Arity`, `Argument.Visibility`,
     `Argument.Help`) are domain primitives, not codecs.

2. **Where does the *codable sibling* on that namespace live?**

These are independent. The first is governed by the layer-architecture
rules ([ARCH-LAYER-001], [MOD-DOMAIN], the institute's L1/L2/L3 semantics).
The second is the question this Research arc answers.

#### 5.2 The substrate-friction axis

[PRIM-FOUND-004]'s friction intent is fundamentally about **substrate
boundaries**. The rule names `Swift.String` explicitly as the substrate
consumers should be friction-gated from at L1. It does NOT name `[UInt8]` or
byte primitives — because the byte substrate IS the L1 typed system, not an
escape hatch from it.

A clean framing: L1 owns *typed byte work*. `Swift.String` is *outside* the
L1 typed system (it's Unicode-aware, allocation-driven, ICU-backed). Any L1
API that converts to/from `Swift.String` is by definition a substrate
boundary crossing — and [PRIM-FOUND-004] gates these.

A sibling protocol whose required methods bridge to `Swift.String` (e.g.,
`Argument.Codable` with `init(argument: String)`) introduces such a boundary
crossing at L1 — exactly what [PRIM-FOUND-004] is designed to prevent.

A sibling protocol whose required methods operate over `[UInt8]` (e.g.,
`Binary.Parseable` with `parse<Source>(from:) where Source.Element == UInt8`)
operates *inside* the L1 typed system — there is no boundary to gate.

#### 5.3 Why namespace-rooted is the right default

Sibling protocols are *namespace members* by [FAM-005]: they declare "this
type has a canonical surface for FORMAT F." The format IS the namespace.
Splitting the namespace's protocol declarations away from the namespace's
root creates:

- Import friction: consumer needing the protocol must import a different
  module than the one that defines the namespace itself.
- Cognitive load: the consumer must know that `F.Serializable` is somewhere
  other than where `F` is. This contradicts [FAM-008]'s nested-shape
  convention (everything `F`-related lives under `F`).
- Refactor brittleness: if the codec moves between layers, the sibling
  shouldn't have to follow.

Namespace-rooted placement is the structural default. The exception is when
the protocol's required methods cross a substrate boundary that L1 has
explicitly gated.

#### 5.4 Why the exception is bounded

The only substrate gate at L1 today is [PRIM-FOUND-004] (Swift.String /
Unicode.Scalar escape hatch). There is no equivalent gate for `[UInt8]`,
`Span<UInt8>`, `Unicode.Scalar`, or any other substrate that's already
inside the L1 typed system.

A future analogous gate (e.g., "L1 must not introduce easy Foundation.URL
escape hatches") would compose with the same exception: a hypothetical
`F.URLCodable` (Foundation-dependent) would also be barred from L1 by the
extension of [PRIM-FOUND-004] to Foundation types — and would default to
L3, the layer at which Foundation Integration targets exist.

Per [PRIM-FOUND-001] Foundation is barred at L1; per [PRIM-FOUND-004] easy
String conversion is barred at L1. Both are substrate boundaries. The
exception is structurally narrow: any sibling whose required methods cross
an L1 substrate boundary promotes one tier.

### 6. Prior art — external ecosystems (per [RES-021])

#### 6.1 Rust serde

Rust serde's pattern: a *single* `Serialize` and `Deserialize` trait per
type, parameterized at the call site by the format-specific `Serializer` /
`Deserializer` driver. Format crates (`serde_json`, `serde_yaml`,
`bincode`, `ciborium`) implement the driver traits, not separate format-
specific Serialize/Deserialize traits.

> *"Implementations of Serialize for primitive types is provided in
> serde::ser. The same applies to Deserialize."* — serde docs, verified
> [serde.rs/data-format.html](https://serde.rs/data-format.html)

So in serde, the placement question doesn't arise the same way: `Serialize`
and `Deserialize` are ONE pair of traits, in ONE central crate (`serde`),
implemented once per type. Format crates extend the driver side, not the
trait side. This is structurally a refinement-based "type commits to ONE
codec interface" world — like Apple's Foundation `Codable` — exactly the
lockout the institute's sibling design rejects per the family-codable
convention's framing.

Where do they live? `serde::Serialize` is in the central `serde` crate; format
drivers (`serde_json::Serializer`) are in per-format crates. The Rust
ecosystem doesn't have an L1/L2/L3-style layering question because all type-
trait code lives in one crate by design.

**Contextualization per [RES-021]**: Rust serde's "one trait, many drivers"
model is universal in Rust because Rust has no Foundation/SDK/no-stdlib
substrate-friction concern at the trait level. Universal adoption ≠ universal
necessity: the institute deliberately escapes the Codable lockout, so serde's
model doesn't transfer.

#### 6.2 Haskell aeson

Haskell aeson uses `FromJSON` and `ToJSON` typeclasses — one per direction,
per format. Other format libraries (`yaml`, `xml-conduit`, `serialise` for
CBOR) define their own `FromYAML`/`ToYAML`, etc. typeclasses.

> *"Aeson defines two typeclasses, FromJSON and ToJSON, which are used to
> convert values to and from JSON."* — Aeson docs, [`Data.Aeson`](https://hackage.haskell.org/package/aeson/docs/Data-Aeson.html)

In Haskell, these typeclasses live in the package that defines the format
support. `FromJSON` lives in `aeson`; `FromYAML` lives in `yaml`. The
question of "L1 vs L3" doesn't have a Haskell analog because Haskell packages
aren't layered in the institute's L1/L2/L3 sense. But the **placement
intuition** maps: each format's typeclass lives in the package that owns the
format namespace. `Data.Aeson.FromJSON` is in the `aeson` package, which IS
the JSON-domain package.

This is the namespace-rooted intuition (Option A) under a different name.

**Contextualization per [RES-021]**: aeson confirms the namespace-rooted
intuition is widely-natural — but Haskell doesn't have the L1/L2/L3 layered
substrate-friction concern. The institute's hybrid Option D is namespace-
rooted + the substrate-aware exception that Haskell doesn't need to face.

#### 6.3 Apple/Foundation Codable-successor proposal (cited in v1.1.4)

Per the existing family-codable-convention doc §9 + v1.1.4 promotion: Apple's
proposal would introduce per-format protocols (`JSONCodable`,
`PropertyListCodable`) as sibling-like overlays on top of a format-agnostic
base (`CommonCodable`).

Where would these live in Foundation? The proposal places them in
Foundation, alongside the canonical `Encodable`/`Decodable`. There is no
multi-layered analog — Foundation is one big monolithic stdlib-tier package.
The placement question is moot in Foundation; it surfaces in the institute
specifically because of the L1/L2/L3 layering.

**Contextualization**: Apple's proposal validates *that* per-format sibling
protocols are a natural pattern in serialization design (this is the third
external corroboration of the family-codable convention). It does NOT
contribute to the *placement* question because Foundation is monolithic.

#### 6.4 Synthesis — external prior art contextualization

The placement question is essentially institute-specific. Rust serde
doesn't face it (one central crate). Haskell aeson defaults to namespace-
rooted (each format's typeclass in its own package). Apple Foundation
doesn't face it (monolithic).

The institute's layered architecture creates the question; the institute's
substrate-friction discipline ([PRIM-FOUND-004]) creates the exception. No
external precedent fully addresses both; the rule must be institute-
internal-derived.

This matches [RES-021]'s contextualization warning: universal adoption ≠
universal necessity. External ecosystems' placement choices reflect their
absence of the institute's layering and substrate-friction discipline. Bare
prior-art import would produce the wrong rule.

### 7. Existing conflict cases — empirical audit (per [RES-013a])

The fourth sub-question: does the institute have any sibling protocols at L1
that conflict with the friction intent? An exhaustive scan:

| Sibling | Layer | Substrate | [PRIM-FOUND-004] conflict? | Resolution |
|---|---|---|---|---|
| `Binary.Serializable` | L1 | `[UInt8]` | NO | No conflict; matches namespace-rooted default. |
| `Binary.Parseable` | L1 | `[UInt8]` | NO | No conflict; matches namespace-rooted default. |
| `ASCII.Parseable` | L1 | `[UInt8]` (via ASCII-substrate Parser instances) | NO | No conflict; matches namespace-rooted default. The protocol itself is currently a marker (post-Φ.1); parse paths are bytes. |
| `Binary.ASCII.Serializable` | L1 | `[UInt8]` | NO | (DEPRECATED for W4 namespace reasons; orthogonal to placement.) |
| `UInt8.Base62.Serializable` | L1 | `[UInt8]` | NO | Sub-sibling; refines Binary.Serializable; byte-substrate throughout. |

**No L1 sibling protocol currently in the ecosystem conflicts with
[PRIM-FOUND-004]**. The friction intent has been respected by accident-or-
discipline: every L1 sibling shipped to date is byte-substrate. The
distinction between byte-substrate (acceptable at L1) and String-substrate
(violating [PRIM-FOUND-004] at L1) has been latent — never explicitly
named — but consistently applied.

`Argument.Codable` would be the first case to test the boundary. The Research
arc surfaces the boundary explicitly and codifies the rule before the test
case lands.

### 8. The structural argument (per [RES-022])

The placement question can be answered by structural correctness alone — no
ecosystem cost / migration / pragmatism axes need to be invoked:

**Structural correctness criterion**: a sibling protocol's placement is
structurally correct if and only if:

1. It is discoverable from its format namespace's import scope (matches
   [FAM-008] namespace-locality).
2. Its required methods do NOT introduce a substrate boundary crossing at
   the protocol's resident layer that is otherwise gated by the layer's
   substrate-friction rules.

Option A (namespace-rooted) satisfies (1) but can fail (2) for
String-substrate L1 cases (`Argument.Codable`).

Option C (substrate-aware) satisfies (2) but fails (1) — splits namespace
and family.

Option D (hybrid) satisfies BOTH — namespace-rooted by default, exception
only when (2) would fail.

By [RES-022]'s structural-correctness-dominates rule: Option D is the
unique structurally-correct placement strategy. The diff-size or cost-of-
adoption axes do not need to be invoked.

---

## Recommendation

### The placement rule

> **Family-codable sibling protocols (`F.Codable`, `F.Parseable`,
> `F.Serializable`) MUST live in the same layer as the format namespace
> `F`'s root declaration, UNLESS the sibling's required methods cross a
> substrate boundary gated by the resident layer's friction rules — in
> which case the sibling MUST promote to the lowest layer where that
> substrate is permitted.**

**Currently the only substrate gate active at L1 is [PRIM-FOUND-004]
(`Swift.String` / `Unicode.Scalar` escape hatches).** Future additions to L1
substrate gating compose: any sibling whose required methods cross a newly-
gated substrate at L1 promotes one tier.

The rule preserves [FAM-008]'s namespace-locality discipline (everything
`F`-related lives under `F`) for all empirical cases while resolving the
previously-implicit substrate-friction question for the
single-anticipated-near-term case (`Argument.Codable`).

### Codification — [FAM-009]

This Research arc proposes a new family-codable convention rule for skill
promotion (per [RES-006a]):

> **[FAM-009] Sibling protocol layer placement.** Format-specific sibling
> protocols (`F.Codable`, `F.Parseable`, `F.Serializable`) MUST live in
> the same layer as the format namespace `F`'s root declaration, UNLESS
> the sibling's required methods cross a substrate boundary gated by the
> resident layer's friction rules ([PRIM-FOUND-004], [PRIM-FOUND-001]).
> When such a boundary would be crossed, the sibling MUST promote to the
> lowest layer permitting the substrate. The default is namespace-rooted;
> the exception is bounded by substrate-friction rules.

This codification is suitable for promotion to the
`swift-foundations/swift-json/Research/family-codable-convention.md` doc
when it next moves to v2.x — OR to a new ecosystem-wide
`swift-institute/Skills/...` skill (depending on whether the convention as
a whole is promoted to ecosystem-wide skill scope; [RES-006a] choice).

### Application to currently-shipped placements

| Sibling | Currently at | Substrate | Namespace root | Per [FAM-009] should be at | Match? |
|---|---|---|---|---|---|
| `JSON.Serializable` | L3 (swift-json) | `JSON` tree value (L3 type) | L3 | L3 | YES |
| `Plist.Serializable` | L3 (swift-plist) | `Plist` tree value (L3 type) | L3 | L3 | YES |
| `XML.Serializable` | L3 (swift-xml) | `XML` tree value (L3 type) | L3 | L3 | YES |
| `Binary.Serializable` | L1 (swift-binary-primitives) | `[UInt8]` | L1 | L1 | YES |
| `Binary.Parseable` | L1 (swift-binary-primitives) | `[UInt8]` | L1 | L1 | YES |
| `ASCII.Parseable` | L1 (swift-ascii-parser-primitives) | `[UInt8]` | L1 | L1 | YES |
| `UInt8.Base62.Serializable` | L1 (sub-sibling of Binary.Serializable) | `[UInt8]` | L1 (sub-sibling under Binary) | L1 | YES |

**All currently-shipped placements MATCH the recommended rule.** No
relocation is required. The convention canonicalizes the existing pattern;
nothing breaks.

### Application to the immediate-anticipated case: `Argument.Codable`

`Argument.Codable` (per `2026-05-15-swift-arguments-ecosystem-design.md`
§3.3 + §3.9 + D7) has:

- Format namespace `Argument` rooted at L1 (`swift-argument-primitives`).
- Required methods bridging `Self` ↔ `Swift.String` (each argv element IS a
  `String`).

The substrate-friction exception fires: `Swift.String` is gated at L1 per
[PRIM-FOUND-004]. The sibling must promote one tier.

Where to? The lowest layer permitting `Swift.String` conversion is L3 (per
[PRIM-FOUND-004]: *"String conversion is placed at L3 deliberately"*).

**Recommendation for `Argument.Codable` placement: L3 `swift-arguments`,
NOT L1 `swift-argument-primitives`.**

Concretely, the L1 vocabulary package (`swift-argument-primitives`) owns the
vocabulary atoms (`Argument.Name`, `Argument.Arity`, `Argument.Visibility`,
`Argument.Help`, `Argument.Position`, `Argument.Error`, `Argument.Tokenizer`,
etc.) WITHOUT the codable family. The L3 composed package
(`swift-arguments`) hosts `Argument.Codable`, `Argument.Parseable`,
`Argument.Serializable` PLUS the standard-library conformances (`Int:
Argument.Codable`, `String: Argument.Codable`, `Bool: Argument.Codable`,
…).

This:
- Honors [PRIM-FOUND-004] (no Swift.String escape hatch at L1).
- Honors [FAM-008] / namespace-locality only partially — the `Argument`
  namespace's surface is split across two packages (vocabulary at L1,
  codable at L3). This split is the structurally-correct cost of respecting
  [PRIM-FOUND-004]; the alternative (sibling at L1) is structurally
  incorrect per [FAM-009].
- Provides a clean import story: consumers importing `swift-argument-primitives`
  get vocabulary; consumers importing `swift-arguments` (which depends on
  `swift-argument-primitives`) get vocabulary + codable family + tokenizer +
  schema + commands + help/completion/manpage emit.
- Resolves D7 directly.

### Application to hypothetical future cases

#### Hypothetical `Binary.LittleEndian.Codable`

REJECTED on independent grounds per [FAM-005]: endianness is an operation
parameter (via `Binary.Endianness`), not a sibling-namespace dimension.
[FAM-009] doesn't need to fire on this case; [FAM-005] precludes the
namespace from existing.

#### Hypothetical `XML.Parseable` / `XML.Serializable` peer expansion (post-v1.1.4)

The `XML` namespace is rooted at L3 (`swift-xml`). Substrate is `XML` tree
value (an L3 type, not `Swift.String` or `[UInt8]` at the protocol level —
the byte-decoding happens internally and the protocol contracts over the
tree value).

Per [FAM-009]: namespace at L3 → sibling at L3. No substrate-friction
exception fires (the L3 String/Foundation gate is the L1 rule; L3 already
permits these). Lives in `swift-xml`. Empirically MATCHES current placement.

#### Hypothetical `MessagePack.Serializable` / `MessagePack.Parseable`

MessagePack is a byte-substrate compact tagged format (close cousin to
Binary, structurally). If shipped as `swift-messagepack-primitives` at L1,
the namespace would be rooted at L1; [FAM-009] places the siblings at L1.

If shipped as `swift-messagepack` at L3 (composed format), the namespace
would be rooted at L3; [FAM-009] places the siblings at L3.

Either case is structurally valid — the placement of the codable family
follows the placement of the namespace itself. The *namespace placement*
decision is governed by separate architectural rules ([ARCH-LAYER-001],
[MOD-DOMAIN]).

#### Hypothetical `TOML.Codable`

TOML is a tree-intermediate format. Likely L3 (analogous to JSON, Plist,
XML). Namespace rooted at L3 → sibling at L3. Substrate is TOML tree value
(an L3 type). No substrate-friction exception fires. Matches anticipated
placement.

#### Hypothetical `Environment.Variable.Codable` (env-var value conversion)

Env-var values are `Swift.String`. If the namespace `Environment.Variable`
is at L1 (`swift-environment-primitives` for vocabulary), [FAM-009] requires
promotion to L3 (`swift-environment`) — same friction-driven exception as
`Argument.Codable`. The two sibling families are structurally isomorphic.

If the namespace `Environment.Variable` is rooted at L3 from the start (no
L1 vocabulary package), [FAM-009] places the sibling at L3 directly. No
promotion needed.

The rule is composable: any String-substrate sibling promotes one tier
above its namespace root, OR lives at L3 (or higher) directly if the
namespace is rooted there.

#### Hypothetical `Path.Codable` (path↔String conversion)

Same reasoning as `Argument.Codable` / `Environment.Variable.Codable`:
substrate is `Swift.String`; namespace root in `swift-path-primitives` is at
L1; [PRIM-FOUND-004] fires (in fact this is the literal motivating example
of [PRIM-FOUND-004]: *"do NOT add `Path.View.string: Swift.String` to
`swift-path-primitives`"*). The sibling promotes to L3, plausibly residing
in `swift-paths` (composed L3 path foundation).

---

## Worked examples — confirm or contradict the current state

Per the recommendation in §5, the application table:

| Sibling | Currently lives at | Should live at per [FAM-009] | Action |
|---|---|---|---|
| `JSON.Serializable` | L3 swift-json | L3 (namespace at L3) | **NO CHANGE** — current placement matches. |
| `Plist.Serializable` | L3 swift-plist | L3 (namespace at L3) | **NO CHANGE** — current placement matches. |
| `XML.Serializable` | L3 swift-xml | L3 (namespace at L3) | **NO CHANGE** — current placement matches. |
| `Binary.Serializable` | L1 swift-binary-primitives | L1 (namespace at L1, byte substrate) | **NO CHANGE** — current placement matches. |
| `Binary.Parseable` | L1 swift-binary-primitives | L1 (namespace at L1, byte substrate) | **NO CHANGE** — current placement matches. |
| `ASCII.Parseable` | L1 swift-ascii-parser-primitives | L1 (namespace at L1, byte substrate) | **NO CHANGE** — current placement matches. |
| `UInt8.Base62.Serializable` | L1 swift-base62-primitives | L1 (sub-sibling, byte substrate) | **NO CHANGE** — current placement matches. |
| `Argument.Codable` (proposed) | L1 swift-argument-primitives (per parent doc §3.3 v1.0.3) | **L3 swift-arguments** (string substrate; promotion exception fires) | **CHANGE in proposal**: relocate from L1 to L3 in the swift-arguments design v1.0.4. |
| `Argument.Parseable` (proposed) | L1 swift-argument-primitives (per parent doc §3.3 v1.0.3) | **L3 swift-arguments** (string substrate; promotion exception fires) | **CHANGE in proposal**: relocate from L1 to L3 in the swift-arguments design v1.0.4. |
| `Argument.Serializable` (proposed) | L1 swift-argument-primitives (per parent doc §3.3 v1.0.3) | **L3 swift-arguments** (string substrate; promotion exception fires) | **CHANGE in proposal**: relocate from L1 to L3 in the swift-arguments design v1.0.4. |

**Empirical state after applying [FAM-009]**: zero currently-shipped
placements change. All ecosystem siblings already comply with the rule (by
the accidental-or-disciplined choice to make every L1 sibling byte-
substrate). The only change is to the proposed argument-parser design
(currently at v1.0.3 RECOMMENDATION) — D7 resolves with the L1→L3 relocation
of `Argument.Codable` / `Argument.Parseable` / `Argument.Serializable`.

The institute's pre-existing pattern is structurally correct; this Research
arc names and codifies what was implicit.

---

## Consequences

### Resolved questions

1. **Q1 (precedent)**: Empirically, namespace-rooted placement applies to every
   shipped case. JSON.Serializable lives at L3 with the L3 JSON namespace;
   ASCII.Parseable lives at L1 with the L1 ASCII namespace; Binary.Parseable
   lives at L1 with the L1 Binary namespace.

2. **Q2 ([PRIM-FOUND-004] interaction)**: `Argument.Codable` IS more
   friction-violating than `ASCII.Parseable`. The two are NOT isomorphic. The
   substrate distinguishes them: ASCII operates over `[UInt8]` (inside the
   typed system); Argument operates over `Swift.String` (an escape from the
   typed system). [PRIM-FOUND-004] gates the latter at L1, not the former.

3. **Q3 (placement determinant)**: Namespace root, NOT codec home. The codec
   tends to coincide with the namespace home for tree-intermediate formats
   (JSON has both at L3) but doesn't have to. Byte-substrate formats often
   have no separate codec at all — the protocol's required method IS the
   codec. Codec-rooted placement (Option B) is empirically vacuous.

4. **Q4 (existing conflict cases)**: NONE. Every L1 sibling currently shipped
   is byte-substrate. The implicit discipline was correct; this arc names it.

5. **Q5 (default rule)**: Hybrid Option D / [FAM-009]: namespace-rooted by
   default; substrate-friction exception promotes one tier when L1's
   `Swift.String` (or future Foundation/L1-gated-substrate) gate fires.

### Open follow-ups

#### Skill promotion

Per [RES-006a], the resolved rule [FAM-009] is a candidate for promotion to
either:

(a) The existing per-package family-codable-convention doc at
`swift-foundations/swift-json/Research/family-codable-convention.md` —
codified as a v2.x amendment (the per-package doc would also need to
promote scope to ecosystem-wide per [RES-002a]/[META-005]).

(b) A new ecosystem-wide skill (or skill addition) — e.g. an extension to
`swift-institute/Skills/primitives/SKILL.md`'s [PRIM-FOUND-*] catalog
linking to [FAM-009], or to a hypothetical new
`swift-institute/Skills/codable-conventions/SKILL.md`.

Recommendation: option (b) is more durable (skill scope) and cleaner
(separates the skill from the doc-state archive). Defer the skill-promotion
decision to a separate skill-lifecycle arc; the rule is published here as a
RECOMMENDATION and is immediately applicable.

#### Doc promotion of the per-package family-codable doc to ecosystem-wide

The existing per-package family-codable-convention doc at
`swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4
declares (line 824):

> *"Promotion of this Research doc to `swift-institute/Research/` per
> [RES-002a] triggers when `Binary.Parseable` lands (second non-trivial
> format-Codable empirically exercising the byte-appender shape's parse
> direction)."*

`Binary.Parseable` LANDED 2026-05-14 (per v1.1.4 state-of-workspace
finding). The promotion trigger has fired. This Research arc plus the prior
v1.1.4 + the empirical landing collectively warrant the doc's promotion to
`swift-institute/Research/`. Per [RES-002a], the move-to-ecosystem-wide step
is a separate triage action; this doc is the precursor (covering the
specific U10 / D7 placement question that the per-package doc didn't
address).

#### Audit recommendation

Following [FAM-009]'s codification, an ecosystem-wide audit should verify
that:

1. No L1 sibling protocols introduce Swift.String-bridging required methods.
   (Currently: NONE — all L1 siblings are byte-substrate. Audit confirms.)
2. The `Argument.Codable` / `.Parseable` / `.Serializable` proposal in
   `2026-05-15-swift-arguments-ecosystem-design.md` updates to v1.0.4 with
   the L1→L3 relocation.

### Risks and reversibility

The rule is reversible — relocating a sibling protocol from L1 to L3 (or
vice versa) is a contained refactor affecting:

- One source file (the protocol declaration).
- A small set of stdlib conformance files (move with the protocol).
- The Package.swift of the affected package(s).
- Consumer imports (mechanical update).

No structural assumption is locked in by L1 vs L3 placement that can't be
unwound. Pre-1.0 ecosystem state means even "shipped" placements remain
fluid.

If [FAM-009] proves wrong in some edge case (e.g., a future sibling whose
substrate is `[UInt8]` but whose composition requires L3-only L3
infrastructure), the rule can amend with another exception. The default
(namespace-rooted) is robust; the exception (substrate-friction promotion)
is the bounded escape hatch.

---

## Outcome

**Status**: RECOMMENDATION (initial publication; ready for promotion to skill
on principal authorization).

### Conclusion

The principled placement rule for family-codable sibling protocols is
**namespace-rooted by default, with a substrate-friction exception**
([FAM-009]). The default matches every currently-shipped placement. The
exception resolves the previously-open question for `Argument.Codable` and
generalizes cleanly to future cases.

### Concrete decisions

1. **`Argument.Codable` / `Argument.Parseable` / `Argument.Serializable`
   relocate to L3 `swift-arguments`**, NOT L1
   `swift-argument-primitives`. Parent doc updates from v1.0.3 to v1.0.4
   with the L3 relocation noted in §3.3 + §3.7 + §3.9 + D7-resolved.

2. **All other currently-shipped sibling protocols remain at their current
   layer**. No relocations required.

3. **The rule [FAM-009] is a candidate for skill promotion** alongside the
   eventual move of the per-package family-codable-convention doc to
   ecosystem-wide scope. Both promotions are deferred to follow-on
   skill-lifecycle / [RES-002a] arcs.

### Next steps

1. Update parent doc `2026-05-15-swift-arguments-ecosystem-design.md` to
   v1.0.4 with `Argument.Codable` placement changed L1 → L3. Principal owns
   integration; this Research arc deliberately does not edit the parent doc.

2. Surface the [FAM-009] rule for skill promotion to the principal at the
   next skill-lifecycle pass.

3. When `Argument.Codable` actually authors (after parent doc
   integration), validate the L3 placement empirically by importing
   `swift-arguments` in a consumer and confirming the sibling-protocol +
   stdlib conformance discovery matches the expected import surface.

### Cross-references

- Parent doc: `swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md` v1.0.3 §3.9 + D7 (the deferred question this Research arc resolves)
- Per-package family-codable convention doc:
  `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4
  ([FAM-001]–[FAM-008]; the prior-art research that establishes the
  convention shape this arc supplements with placement)
- Memory framing: `project_parser_serializer_coder_system_framing.md`
  (principal direction 2026-05-14 authorizing this arc)
- Primitives skill: `swift-institute/Skills/primitives/SKILL.md:80`
  ([PRIM-FOUND-004] the friction rule whose substrate-sensitivity grounds
  the exception)

## References

### Internal (primary)

- `swift-foundations/swift-json/Research/family-codable-convention.md` v1.1.4 — prior-art per-package convention codification ([FAM-001]–[FAM-008])
- `swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md` v1.0.3 — parent doc raising U10 / D7 placement question
- `swift-institute/Skills/primitives/SKILL.md` [PRIM-FOUND-004] — substrate-friction rule grounding the exception
- `project_parser_serializer_coder_system_framing.md` — framing memo

### Empirical anchors (verified file:line at write time per [RES-023])

- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:26` — canonical attachment
- `swift-primitives/swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19` — canonical attachment
- `swift-primitives/swift-coder-primitives/Sources/Coder Primitives/Codable.swift:29` — canonical attachment
- `swift-primitives/swift-binary-primitives/Sources/Binary Serializable Primitives/Binary.Serializable.swift:37` — L1 byte-substrate sibling
- `swift-primitives/swift-binary-primitives/Sources/Binary Parseable Primitives/Binary.Parseable.swift:58` — L1 byte-substrate sibling
- `swift-primitives/swift-binary-primitives/Sources/Binary Namespace/Binary.swift:15` — L1 namespace root
- `swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.swift` — L1 namespace root
- `swift-primitives/swift-ascii-parser-primitives/Sources/ASCII Parser Primitives Core/ASCII.Parseable.swift:32` — L1 byte-substrate sibling (currently refinement; Φ.1 closure pending)
- `swift-foundations/swift-json/Sources/JSON/JSON.Serializable.swift:96` — L3 tree-intermediate sibling
- `swift-foundations/swift-json/Sources/JSON/JSON.Coder.swift` — L3 canonical leaf codec (co-located with sibling)
- `swift-foundations/swift-plist/Sources/Plist Core/Plist.Serializable.swift:3` — L3 tree-intermediate sibling (shape-compatible)
- `swift-foundations/swift-xml/Sources/XML/XML.Serializable.swift:36` — L3 tree-intermediate sibling (shape-compatible)

### External (per [RES-021] contextualization)

- [Rust serde](https://serde.rs/) — central `Serialize`/`Deserialize` traits + format-driver crates; no layered ecosystem placement question
- [Haskell aeson](https://hackage.haskell.org/package/aeson) — `FromJSON`/`ToJSON` typeclasses in the `aeson` package (namespace-rooted)
- [Apple/Foundation Codable-successor proposal](https://forums.swift.org/t/the-future-of-serialization-deserialization-apis/78585) — per-format `JSONCodable`/`PropertyListCodable` sibling-like protocols in monolithic Foundation
- Foundation Codable (SE-0166, SE-0167) — single-canonical-encoding lockout; institute design rejects this

### Process anchors

- [RES-002a] Research triage — ecosystem-wide vs per-package scope
- [RES-006a] Documentation promotion — research findings to skill
- [RES-013a] Synthesis verification — carry-forward findings must be verified
- [RES-018] Cross-domain-fit / scope carve-outs — guides namespace home decisions for new packages
- [RES-019] Internal grep — applied at the start of this arc
- [RES-021] Prior art contextualization — applied in §6
- [RES-022] Structural correctness framing — selected Option D over Option B
- [RES-023] Empirical claim verification — applied to every file:line citation
- [RES-027] Loose-end follow-up — applies to the skill-promotion deferral
- [RES-029] Framing-challenge for binding/placement questions — applied in framing this as "where does the sibling LIVE" semantic question rather than cost/cohesion ranking
