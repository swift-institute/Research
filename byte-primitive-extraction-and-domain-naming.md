# Byte Primitive Extraction and Domain Naming

<!--
---
version: 1.1.1
last_updated: 2026-05-26
status: SUPERSEDED
tier: 2
# Tier bumped 1 → 2: this doc lands an ecosystem-wide naming rule via skill
# promotion ([API-NAME-001b]), not a package-specific decision. [RES-020]
# tier-1 framing ("package-specific, no precedent-setting") understates the
# rigor here. Capability-marker generalization is tracked separately in
# HANDOFF-byte-protocol-capability-marker.md, not via a dual status here.
scope: ecosystem-wide
supersedes: HANDOFF-byte-extraction-arc.md (2026-05-15, deleted on landing)
---
-->

> **SUPERSEDED 2026-05-26** by [`operation-domain-naming-and-organization.md`](operation-domain-naming-and-organization.md), the definitive operation-domain naming/organizing convention. Naming content ([API-NAME-001b] subject-first) is absorbed there; the byte→L1 extraction decision in this doc is executed and remains the record for that decision.

## Context

The byte concept was buried inside `swift-parser-primitives` as `Parser.Byte` (a parser
combinator) and `Parser.Input.Bytes` (a parser-flavored byte cursor). There was no
first-class `Byte` value type — every consumer parsing bytes was forced to either
`UInt8`-at-the-edge or to import parser machinery to get a byte type. Both options
mis-placed the boundary: `Byte` is not a parser concept, it is a primitive value type
that the parser happens to consume.

This arc extracted `Byte` to its own L1 package and split `Byte.Parser` (the parser
specialization for byte input) out as a sibling L1 package. The structural changes
landed; this document records the architectural decisions cemented along the way and
the open questions queued for follow-up sessions.

The decisions below are cross-cutting and apply beyond the byte case — they govern
how every future L1 domain (text, scalar, line, codepoint, …) splits between
"the value type" and "the parser specialization."

## Decisions Cemented

### 1. LargerDomain.Subdomain Ordering (Subject-First When Domain Exceeds Role)

**Decision**: When a type sits at the intersection of two domains where one is
strictly larger than the other, the namespace MUST order the larger domain first.
`Byte.Parser`, not `Parser.Byte`. `ASCII.Parser`, not `Parser.ASCII`.

**Decision test**: For a candidate type at the intersection of domains X and Y:

| Question | If yes | If no |
|----------|--------|-------|
| Is X a kind of Y (X is a Y-variant)? | `Y.X` — nest X under Y | Continue. |
| Is X a Y-domain operation on a non-Y subject? | `Subject.Y_specialization` — nest under subject | Continue. |
| Are X and Y peer concepts? | The ordering is a judgment call; document the rationale | — |

**Examples**:

| Type | Shape | Why |
|------|-------|-----|
| `Parser.Many` | `Y.X` (variant) | `Many` is a kind of `Parser`. |
| `Byte.Parser` | `Subject.Specialization` | A byte parser is byte-domain; parsing is the role. The byte is the subject. |
| `ASCII.Parser.Decimal` | `Subject.Specialization.X` | Same pattern — ASCII is the larger domain, parser is the role specialization. |
| `RFC_4122.UUID` | spec-mirroring (see [API-NAME-003]) | Specification-defined; ordering follows the spec namespace. |

**Why this is a rule, not a preference**: prior to formalization, this ordering
emerged ad-hoc — `ascii-parsing-domain-ownership.md` v4.2.0 RECOMMENDATION
(2026-03-04) was the first instance, framed as "subject-first namespace ordering"
specific to ASCII vs `Binary.ASCII`. The byte arc surfaced the same question on a
different domain pair (`Byte` × `Parser`) and reached the same conclusion. Two
instances of the same pattern across independent domain pairs justify promoting the
ordering from a domain-specific recommendation to a code-surface rule that applies
uniformly across the institute.

**Promoted to skill**: code-surface SKILL.md `[API-NAME-001b]` LargerDomain.Subdomain
— Subject-First When Domain Exceeds Role. Companion to `[API-NAME-001]` (Nest.Name)
and `[API-NAME-003]` (Specification-Mirroring Names).

**Cross-references**: [`ascii-parsing-domain-ownership.md`](./ascii-parsing-domain-ownership.md)
v4.2.0 (prior single-domain instance), `[API-NAME-001]`, `[API-NAME-001a]`,
`[API-NAME-003]`.

### 2. Byte Location Split: Value Type at L1, Parser-Adapted Input at L1 Sibling

**Decision**: `Byte` (the value type) lives in `swift-byte-primitives` with zero
parser dependencies. `Byte.Input` (the parser-adapted byte cursor) lives in
`swift-byte-parser-primitives` as a sibling L1 package that depends on `Byte`,
`Input`, and `Parser`.

**Layout**:

| Package | What it owns | Deps |
|---------|--------------|------|
| `swift-byte-primitives` | `Byte` struct, `Byte.Protocol`, Carrier integration, bitwise extensions | `carrier-primitives` only |
| `swift-byte-parser-primitives` | `Byte.Parser`, `Byte.Literal.Parser`, `Byte.Input` typealias, `Parser.Builder+Literal`, `Parseable+Byte.Input` | `byte-primitives`, `parser-primitives`, `input-primitives`, `array-primitives`, `either-primitives` |

**Why two packages instead of one**: a downstream consumer that only needs the
byte concept (e.g., a binary format describing a header field) should not be forced
to pull in parser combinators. The Foundation-free, parser-free `Byte` is reusable
in serializer contexts, coder contexts, schema contexts — none of which need
`Parser.Protocol`. Bundling them would force the byte concept to inherit the
parser stack's dependencies; splitting them lets the byte concept stand alone.

**Why both at L1**: `Byte.Input` is a parser-specialized type, not a higher-layer
composition. It belongs at the same architectural tier as `Parser.Input` /
`Input.Slice` / `Input.Streaming`. The split is horizontal (within L1) not
vertical (across layers).

**Type definition** (canonical — actual shape across the three source files):

```swift
// In swift-byte-primitives — Sources/Byte Primitives/Byte.swift:
@frozen
public struct Byte {
    public let underlying: UInt8
    public init(_ underlying: consuming UInt8) {
        self.underlying = underlying
    }
}
extension Byte: Sendable {}

// In swift-byte-primitives — Sources/Byte Primitives/Byte.Protocol.swift:
extension Byte {
    public protocol `Protocol`:
        Carrier.`Protocol`, Sendable, Equatable, Hashable, Comparable,
        ExpressibleByIntegerLiteral
        where Underlying == UInt8 { }
}
extension Byte: Byte.`Protocol` {}

// In swift-byte-parser-primitives — Sources/Byte Parser Primitives/Byte.Input.swift:
extension Byte {
    public typealias Input = Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>
}
```

The `Input.Slice` form (not `Input.Buffer<[UInt8]>`) was chosen because `Input.Buffer`
is `~Copyable`, which propagates into generic parameter constraints and forces every
downstream parser to opt out of Copyable. `Input.Slice<Array<UInt8>.Indexed<UInt8>>`
provides conditional Copyable via `Base: Copyable`, which is the more general shape.

### 3. Input as Peer-Foundational Namespace (Parser.Input Deletion)

**Decision**: The `Input` namespace is peer-foundational — it sits at the same
architectural level as `Parser` and `Serializer`, not nested inside them. The
re-exports `Parser.Input.*` that existed in `swift-parser-primitives` were deleted
entirely; consumers now reference `Input.Protocol`, `Input.Slice`,
`Input.Streaming`, etc., directly from `swift-input-primitives`.

**What was deleted** (Phase A + B + C of the sister arc):

| Old shape | New shape | Sites |
|-----------|-----------|-------|
| `Parser.Input.Protocol` | `Input.Protocol` | ~57 |
| `Parser.Input.Bytes` | `Byte.Input` (in byte-parser-primitives) | ~60 |
| `Parser.Input.Streaming` | `Input.Streaming` | ~31 |
| Various `Parser.Input.*` | `Input.*` direct | ~148 total |

**Empirical evidence for peer-foundational status**: at the time of deletion,
`swift-input-primitives` had **7 non-parser direct package consumers** (verified
2026-05-15 via `Package.swift` dependency resolution across the L1 ecosystem):

| Package | Domain |
|---------|--------|
| `swift-binary-coder-primitives` | Binary coder |
| `swift-infinite-primitives` | Infinite sequence / lazy streams |
| `swift-dictionary-primitives` | Collection |
| `swift-list-primitives` | Collection |
| `swift-queue-primitives` | Collection |
| `swift-heap-primitives` | Collection |
| `swift-terminal-primitives` | Terminal / TTY I/O |

Plus the parser-side consumers `swift-parser-primitives`,
`swift-binary-parser-primitives`, and (post-this-arc) `swift-byte-parser-primitives`.
A type with seven non-parser direct consumers is not "the parser's input namespace"
— it is a peer abstraction that the parser, among others, consumes. The
`Parser.Input.*` namespace was a re-export convenience that obscured the type's
actual ownership; deletion makes the ownership truthful.

**What got harder**: inside `extension Parser` scopes, `Input.X` is now ambiguous
between the `Input` associated type (in `Parser.Protocol`) and the `Input`
namespace (in `Input_Primitives`). Three to five call sites now require
`Input_Primitives.Input.X` qualification per `[MOD-015a]`. This cost is treated as
intentional (see Section 5 below).

### 4. Byte.Protocol as Refinement of Carrier.Protocol<UInt8> + Stdlib Basics

**Decision**: `Byte.Protocol` is a refining protocol, not a typealias.

```swift
extension Byte {
    public protocol `Protocol`:
        Carrier.`Protocol`,
        Sendable, Equatable, Hashable, Comparable, ExpressibleByIntegerLiteral
    where Underlying == UInt8 { }
}
```

**Why refinement over typealias**: a typealias would make `Byte.Protocol` a synonym
for `Carrier.Protocol where Underlying == UInt8`. That works for byte-shaped values
but loses the ability to add byte-specific affordances (bitwise operations, byte-level
comparison, byte-literal expression) to the protocol surface in one place. The
refinement form lets `Byte.Protocol` accumulate byte-specific defaults while
remaining a strict subset of `Carrier.Protocol`'s capability surface.

**Why these specific protocols**: each is justified.

| Protocol | Justification |
|----------|--------------|
| `Carrier.Protocol where Underlying == UInt8` | Establishes that a `Byte.Protocol` value carries a UInt8 — the structural commitment. |
| `Sendable` | Bytes are value types with no reference semantics; Sendable is free. |
| `Equatable`, `Hashable` | Bytes are compared and hashed pervasively (byte-stream matching, hash tables of byte keys). |
| `Comparable` | Byte-stream parsing depends on byte comparison (e.g., `b >= 0x30 && b <= 0x39` for ASCII digits). |
| `ExpressibleByIntegerLiteral` | Byte literals (`0x41`, `0xFF`) are the natural way to write byte constants in tests and parsers. |

**Conformers**: `Byte` itself, and any consumer-domain newtype that wants to be
"a byte by structure but a foo by intent" (e.g., `ASCII.Byte`, `Latin1.Byte`,
`UTF8.Code_Unit`). The conforming type provides the domain meaning; `Byte.Protocol`
provides the byte affordances.

**Open question (deferred)**: should `UInt8` conform to `Byte.Protocol`? The
arguments are balanced:

- **For**: `UInt8` is structurally a byte; conformance lets generic byte algorithms
  work on raw `UInt8` without a wrapping step at every call site.
- **Against**: `UInt8` is the stdlib's byte representation, which carries semantics
  the institute deliberately avoids (`Numeric`, `BinaryInteger`, `FixedWidthInteger`).
  Adding `Byte.Protocol` conformance to `UInt8` would imply that anywhere `UInt8`
  appears, the byte-typed API is available — including in `Foundation` / `stdlib`
  contexts where the institute prefers explicit wrapping.

Deferred to the capability-marker Tier 3 session ([HANDOFF-byte-protocol-capability-marker.md](../../HANDOFF-byte-protocol-capability-marker.md)).

### 5. Parser.Input Qualification: The Cost IS the Contract

**Framing**: deleting the `Parser.Input.*` re-exports moves ~148 call sites from
implicit (`Parser.Input.X`) to explicit (`Input_Primitives.Input.X` inside
`extension Parser` scopes). This is not a cost to minimize — it is the architectural
contract surfaced syntactically.

**Why the qualification IS the architectural meaning**:

| Site | What it says |
|------|--------------|
| `Parser.Input.Protocol` (old) | "Input is the parser's input namespace" (false — 8 non-parser consumers) |
| `Input.Protocol` (new, outside Parser scope) | "Input is a peer namespace" (true) |
| `Input_Primitives.Input.Protocol` (new, inside Parser scope) | "I'm in a Parser scope where `Input` is an associated type; I want the Input *namespace*" (true; qualification disambiguates) |

The third form is verbose because the situation IS ambiguous — `Parser.Protocol`
has an `Input` associated type AND there is an `Input` namespace, and inside an
extension on `Parser.Protocol`, `Input` could mean either. The qualification is the
compiler asking the author to commit to one meaning. Treating that as a "tax" is a
category error: the architecture demands that the author distinguish "the input
type parameter" from "the Input namespace," and the qualification is how the
distinction reaches the syntax.

**Implication for future arcs**: when a peer-foundational namespace and an
associated-type-in-a-protocol share a name (e.g., `Output`, `State`, `Token`), do
NOT introduce re-exports to paper over the ambiguity. The qualification cost is
constant per call site (a few dozen across the ecosystem); the architectural
clarity is permanent.

## Empirical Findings

### Binary-Stack Audit: GREEN

**Audit scope**: five binary packages were audited (2026-05-15) to determine whether
they reimplement byte concepts that should depend down on `swift-byte-primitives`
or `swift-byte-parser-primitives`. The sister-arc items 5 and 6 in the original
extraction-arc handoff queued this as deferred work.

**Outcome**: all five packages comply with Domains-as-Namespaces; no fixes needed.

| Package | Status | Why |
|---------|--------|-----|
| `swift-binary-primitives` | GREEN | Operates at the integer/bit level; does not wrap UInt8 as a semantic byte type. |
| `swift-binary-parser-primitives` | GREEN | Defines `Binary.Bytes.Input` and `Binary.Bytes.Machine` as Binary-domain capabilities, mirroring the Byte.Parser precedent. |
| `swift-binary-base-primitives` | GREEN | Base-N encoding (RFC 4648); operates on binary digits, not on bytes-as-such. |
| `swift-binary-coder-primitives` | GREEN | Coder-shaped wrappers over binary parsers; no byte reimplementation. |
| `swift-binary-leb128-primitives` | GREEN | LEB128 is a length-encoded integer format; operates on bit-shifted integer accumulators, not on bytes as semantic values. |

**Architectural reading**: `Binary` is the encoding/representation domain. `Byte`
is the value-type domain. They are peer subjects, not consumer/producer. The
binary stack neither needs nor wants `swift-byte-primitives` as a dependency, and
introducing one would create a phantom layering (the binary stack would suddenly
appear to "use bytes" when it actually uses integers and bit-shifts).

**Open follow-up (separate question)**: subsumed by
[`byte-cursor-primitive-unification.md`](./byte-cursor-primitive-unification.md)
v1.1.0 (2026-05-14, status DEFERRED), which classifies the byte-cursor
unification question as `[RES-018]` case (a) — cross-cutting primitive intended
for re-use across unrelated domains — and lays out the Phase 1 / 2 / 3 composition-
check, cost-benefit, and recommendation gates. That doc was authored one day
before this arc landed; the `Binary.Bytes.Input` vs `Byte.Input` question is the
owned-layer instance of the same arc and does not need fresh re-framing.

### Consumer Migration: Clean Across 6 Packages

Six packages were migrated to the new shape: `swift-binary-parser-primitives`,
`swift-parser-machine-primitives`, `swift-ascii-parser-primitives`,
`swift-glob-primitives`, `swift-version-primitives`, `swift-rfc-9110`. Each
required: rename `Parser.Input.*` references, add `swift-byte-parser-primitives`
dep where `Byte.Input` is used, qualify `Input.X` inside `extension Parser` scopes
as `Input_Primitives.Input.X` where ambiguous.

The migration revealed two infrastructure friction points that surfaced as
research candidates:

- `forEach` erases typed throws per `[API-ERR-005]` — the stdlib migration to
  typed-throws is incomplete. Worked around in tests with `@Test(arguments:)`
  parameterized tests. Queued for future research as a stdlib-completeness question.
- Cross-module extension nested-type visibility per `[MOD-028]` and module
  qualification for namespace shadowing per `[MOD-015a]` are now load-bearing for
  the peer-foundational namespace shape; both rules were known but received fresh
  empirical pressure from this arc.

## Open Questions and Deferred Work

| Topic | Where queued | Why deferred |
|-------|--------------|--------------|
| `UInt8: Byte.Protocol`? capability-marker generalization | [HANDOFF-byte-protocol-capability-marker.md](../../HANDOFF-byte-protocol-capability-marker.md) (Tier 3) | Requires prior-art research (Rust trait coherence, Haskell typeclass composition, Scala typeclass-as-marker) before deciding. Branching to a fresh session lets the research breathe. |
| `Binary.Bytes.Input` vs `Byte.Input` unification | [`byte-cursor-primitive-unification.md`](./byte-cursor-primitive-unification.md) v1.1.0 | Classified as `[RES-018]` case (a) DEFERRED with Phase 1/2/3 plan; one day older than this arc. |
| swift-linter run on parser-primitives | [HANDOFF-byte-arc-followups.md](../../HANDOFF-byte-arc-followups.md) | User-gated. Linter still in active development; user signals when ready. |
| parser-primitives test-scaffolding ByteInput cleanup | [HANDOFF-byte-arc-followups.md](../../HANDOFF-byte-arc-followups.md) | Test Support cleanup; not blocking. |
| swift-linter buildExpression rule amendment | [HANDOFF-byte-arc-followups.md](../../HANDOFF-byte-arc-followups.md) | NOTE handed off to linter agent in package. |
| Byte+Bitwise lift to Carrier SLI | [HANDOFF-byte-arc-followups.md](../../HANDOFF-byte-arc-followups.md) | Could generalize bitwise to all `Carrier.Protocol where Underlying: FixedWidthInteger`; deferred pending design decision. |
| Serializer-side parallel extraction | [HANDOFF-byte-arc-followups.md](../../HANDOFF-byte-arc-followups.md) — **RESOLVED 2026-05-18** at `swift-primitives/swift-byte-serializer-primitives` (Item 6 closed). Mechanical mirror per [API-NAME-001b]; three asymmetries from the parser side documented (Failure = Never; no separate reverse role; no Byte.Buffer typealias). | Mirror arc for `Serializer.Byte` → `Byte.Serializer`; same pattern, different domain. |

## References

- [`ascii-parsing-domain-ownership.md`](./ascii-parsing-domain-ownership.md)
  v4.2.0 RECOMMENDATION — prior single-domain instance of subject-first ordering.
- `swift-byte-primitives` — the L1 package landed by this arc.
- `swift-byte-parser-primitives` — the L1 sibling landed by this arc.
- `swift-input-primitives` — the peer-foundational namespace whose status this arc
  surfaced.
- code-surface SKILL.md `[API-NAME-001]` Nest.Name Pattern.
- code-surface SKILL.md `[API-NAME-001a]` Single-Type-No-Namespace Rule.
- code-surface SKILL.md `[API-NAME-001b]` LargerDomain.Subdomain (promoted by this
  arc).
- code-surface SKILL.md `[API-NAME-003]` Specification-Mirroring Names.
- `[MOD-015a]` module qualification for namespace shadowing.
- `[MOD-028]` cross-module extension nested-type visibility.

## Changelog

- **v1.0.0** (2026-05-15): Initial decision record. Captures the four cemented
  decisions (subject-first ordering, byte location split, Input peer-foundational
  status, Byte.Protocol as refinement) plus the Parser.Input qualification framing
  and the binary-stack audit GREEN finding. Supersedes
  `HANDOFF-byte-extraction-arc.md`.
