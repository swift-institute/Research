# ASCII.Code Structural Shape

<!--
---
version: 1.0.0
last_updated: 2026-05-16
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to: [swift-ascii-primitives, swift-byte-primitives, swift-ascii-parser-primitives, swift-terminal-primitives, swift-foundations/swift-ascii]
normative: false
depends_on:
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
  - swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md
  - swift-primitives/swift-ascii-primitives/Research/ascii-primitives-rawvalue-underlying-rename.md
---
-->

## Context

The 2026-05-15 byte extraction arc (`byte-primitive-extraction-and-domain-naming.md` v1.0.1 DECISION) landed `Byte.Protocol` in `swift-byte-primitives` and named the per-domain capability-marker recipe as the canonical pattern. The subsequent Tier 3 discharge (`byte-protocol-capability-marker.md` v1.1.0 RECOMMENDATION) identified `ASCII.Code` explicitly as one of the expected per-domain conformers:

> **Conformers**: `Byte` itself, and any consumer-domain newtype that wants to be "a byte by structure but a foo by intent" (e.g., `ASCII.Code`, `Latin1.Byte`, `UTF8.Code_Unit`). … Future byte-domain types (ASCII.Code, Latin1.Byte, UTF8.Code_Unit, RFC-specific byte types) conform here to inherit byte-domain operations without re-implementing per-type.
> — `Byte.Protocol.swift`:63–66 and `byte-protocol-capability-marker.md` §"Conformers"

The current `ASCII.Byte` (in `swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Byte.swift`) is a hand-rolled wrapper:

```swift
extension ASCII {
    public struct Byte: Sendable {
        public let rawValue: UInt8
        @_transparent public init(rawValue: UInt8) { self.rawValue = rawValue }
    }
}
```

It predates `Byte.Protocol`; it carries its own classification/parsing/constants extensions (`ASCII.Byte+Classification.swift`, `ASCII.Byte+Constants.swift`, `ASCII.Byte+Parsing.swift`) without participating in the byte-domain protocol family.

Two settled-pre-research decisions frame this Tier 2 arc:

1. **Naming**: `ASCII.Code` is the canonical name per `[API-NAME-003]` specification-mirroring. INCITS 4-1986 uses "code" / "code point" terminology, not "byte". The rename `ASCII.Byte → ASCII.Code` is part of this arc regardless of which structural shape wins. The principal cemented the naming pre-research; this document does not re-litigate it.

2. **Scope**: only the **structural shape** of `ASCII.Code` is open. Three shapes are on the table:
   - **a-Code**: standalone `struct ASCII.Code` wrapping `UInt8` + `Byte.Protocol` conformance.
   - **b-Code**: `typealias ASCII.Code = Tagged<ASCII, Byte>` with `Byte.Protocol` conformance picked up recursively via `extension Tagged: Byte.Protocol where Underlying: Byte.Protocol, Tag: ~Copyable`.
   - **c-Code**: standalone `struct ASCII.Code` wrapping `Byte` (the institute's `Byte` type, not `UInt8`) + `Byte.Protocol` conformance.

Default mode is advisory. This document produces the Tier 2 RECOMMENDATION; principal authorizes implementation separately.

## Question

Which of (a) (b) (c) is the structurally correct shape for `ASCII.Code`?

Per `[RES-029]` (Framing-Challenge for Binding/Membership/Placement Questions), the question is a semantic-identity question first ("what does `ASCII.Code` IS-A?"), with cost / migration / ergonomics as tiebreakers among structurally-valid options per `[RES-022]` (Recommendation-Section Framing Heuristic). The ranking-axis priority:

| Tier | Axis | Disposition |
|------|------|-------------|
| 1 | Semantic identity (IS-A, where-does-it-live) | What is ASCII.Code's relationship to Byte? Is it a peer byte-domain type, a tagged-phantom wrapping of Byte, or a byte-with-extra-semantics? |
| 2 | Operational behavior of adjacent ecosystem types | What shape do `Byte`, `Memory.Address`, `Index<Element>`, `Latin1.Byte` (anticipated) take? |
| 3 | Cost / migration / ergonomics / dependency surface | Engaged ONLY if Tiers 1+2 leave multiple options structurally valid. |

## Prior Art Summary

Five prior research documents establish the constraints this arc operates under. Each is cited as a constraint, not re-derived.

### 1. `byte-protocol-capability-marker.md` v1.1.0 (Tier 3 RECOMMENDATION)

Two findings load-bearing for this arc:

- **Q1 closure**: `UInt8` MUST NOT conform to `Byte.Protocol`. The bundle-conflict analysis (operator shadow, API-surface broadening, Carrier-protocol composition with `Tagged<_, UInt8>`) closed this question. Conformance is restricted to institute byte-domain types + recursive `Tagged<Tag, T: Byte.Protocol>`.

- **Q2 closure**: the per-domain manual recipe IS the canonical capability-marker pattern. Future byte-domain types (`ASCII.Code` named explicitly) follow the recipe. Meta-protocols are blocked by `[IMPL-102]`; generator macros hide the sibling-vs-refinement structural decision.

- **§1.2.1 Recursion-vs-Refinement Constraint Principle**: refinement-of-Carrier X.Protocol forms (`X.Protocol: Carrier.Protocol where Underlying == U`) BLOCK recursive Tagged conformance because `Tagged<Tag, X>.Underlying == X` (per Tagged's universal Carrier conformance), not the bottom-most carrier type. Sibling form is required when recursive Tagged conformance is needed. **`Byte.Protocol` is the sibling form** (with `var byte: Byte { get }` accessor, decoupled from Carrier's `Underlying`). The recursive `Tagged: Byte.Protocol where Underlying: Byte.Protocol, Tag: ~Copyable` extension exists and is the mechanism by which a `Tagged<X, Byte>` value inherits byte-domain semantics.

### 2. `byte-primitive-extraction-and-domain-naming.md` v1.0.1 (Tier 2 DECISION)

The arc that cemented `Byte.Protocol`. §"Why these specific protocols" (Carrier + Sendable + Equatable + Hashable + Comparable + ExpressibleByIntegerLiteral) enumerates the byte-domain capability bundle. §"Conformers" identifies `ASCII.Byte` (→ `ASCII.Code` after this arc), `Latin1.Byte`, `UTF8.Code_Unit` as expected conformers. This is the doc that says "ASCII.Code, by structural intent, IS a byte-domain conformer of Byte.Protocol."

### 3. `protocol-abstraction-for-phantom-typed-wrappers.md` v1.4.0 (Tier 3 DECISION/IMPLEMENTED)

The canonical per-type `X.Protocol` pattern (the "recipe" Byte.Protocol instantiates). §"The Protocol Abstraction Pattern (Phased)" establishes the recipe; §"Generalization Decision" rejects unified-protocol alternatives. The doc IS the mechanism by which classification methods can attach to a Tagged-wrapped value via the recursive conformance extension — see §"Live-Fire Precedent: The Cardinal.Protocol Sibling" for the six-package live-fire of the same recipe (Tagged-recursive operator unification).

### 4. `ascii-primitives-rawvalue-underlying-rename.md` (per-package, 2026-05-03)

`ASCII.Byte`'s `rawValue` is pre-authorized for the `rawValue → underlying` rename. The doc records: "hand-rolled `public let rawValue` types are pre-authorized for the rename. No other types qualify; no other rename action required." Crucially, the rename is **separate from the structural-shape decision** — it lands mechanically if shape (a) or (c) wins; becomes moot if (b) wins (Tagged uses `underlying` already, and `ASCII.Code = Tagged<ASCII, Byte>` inherits that).

### 5. `Index<Element> = Tagged<Element, Ordinal>` + `Memory.Address = Tagged<Memory, Ordinal>` — live-fire typealias-over-Tagged precedents

`swift-index-primitives/Sources/Index Primitives Core/Index.swift`:38 defines `Index<Element>` as a generic typealias over Tagged. `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Address.swift`:54 defines `Memory.Address = Tagged<Memory, Ordinal>` as a **concrete** (non-generic) typealias over Tagged. Memory.Address attaches its ~30 domain-specific affordances (pointer-init, `bitPattern`, `mutablePointer`, `pointer`) via constrained extensions of the form `extension Tagged where Tag == Memory, Underlying == Ordinal { ... }`. This is the ecosystem's existing precedent for option (b)'s shape: concrete typealias-over-Tagged + constrained extensions hosting the per-domain API surface.

## Verified Inherited State (from prior subagent, do NOT re-derive)

### Consumer surface (workspace-wide grep, executed by prior subagent)

| Consumer category | Files | Sites | Use shape |
|---|---:|---:|---|
| `ASCII.Byte.<const>` static accesses (terminal-primitives: Terminal.Input.Parser{,+CSI,+Control,+Mouse}.swift) | 4 | 36 | Constants typed `UInt8`, not `ASCII.Byte` — deliberate for `Collection<UInt8>` comparison |
| `ASCII.Byte` extension (`swift-foundations/swift-ascii/.../ASCII.Byte+INCITS_4_1986.swift`) | 1 | 1 | Touches `rawValue` |
| Stored property / parameter / return type of `ASCII.Byte` outside defining package | **0** | **0** | — |
| `.ascii.X` ephemeral accessor (json, standards, etc.) | many | 283 | Instance constructed on demand, consumed immediately, never stored |

The **type-level migration surface is zero**: no workspace file uses `ASCII.Byte` as a typed value (stored property, parameter, return type). The migration scope is 36 static-constants accesses + 1 rawValue access + 283 ephemeral accessor calls. The ephemeral accessor call sites keep their `.ascii.X` path; only the return type's name changes.

### Verified package HEAD commits (byte arc closed 2026-05-16)

- swift-byte-primitives: `fbccde4`
- swift-byte-parser-primitives: `3d32c41`
- swift-parser-primitives: `eb01abd`
- swift-parser-machine-primitives: `64275b1`
- swift-ascii-parser-primitives: `fa7b5a8`

### swift-ascii-primitives Package.swift surface

Currently **zero dependencies** (`dependencies: []`); Tier 0 leaf. Adopting `Byte.Protocol` requires adding `.package(path: "../swift-byte-primitives")` (which transitively pulls `swift-carrier-primitives` + `swift-tagged-primitives`). This is true for shapes (a), (b), and (c) — none of the three shapes can pick up Byte.Protocol without depending on swift-byte-primitives.

## Design Space

### Shape (a) — Standalone `struct ASCII.Code` wrapping `UInt8` + Byte.Protocol conformance

```swift
extension ASCII {
    public struct Code: Sendable {
        public let underlying: UInt8

        @inlinable
        public init(_ underlying: consuming UInt8) {
            self.underlying = underlying
        }
    }
}

extension ASCII.Code: Byte.`Protocol` {
    public typealias Domain = Never  // bare ASCII.Code is unscoped

    @inlinable
    public var byte: Byte { Byte(underlying) }

    @inlinable
    public init(_ byte: Byte) {
        self.underlying = byte.underlying
    }
}

extension ASCII.Code: Equatable {}
extension ASCII.Code: Hashable {}
extension ASCII.Code: Comparable {}
extension ASCII.Code: ExpressibleByIntegerLiteral {}
```

`Byte.Protocol` default impls (zero/max, `==`, `hash(into:)`, `<`, `init(integerLiteral:)`) provide the stdlib basics. Classification methods + constants + parsing remain in `ASCII.Code+Classification.swift` / `ASCII.Code+Constants.swift` / `ASCII.Code+Parsing.swift` — direct extensions on the concrete type, mechanically renamed from the existing `ASCII.Byte+*` files.

**Storage**: `UInt8` (parallels current `ASCII.Byte` shape).

**Migration**: rename `ASCII.Byte → ASCII.Code` mechanically + replace the hand-rolled `rawValue/init(rawValue:)` pair with the `underlying`/`init(_:)` Byte.Protocol-conforming shape. The `rawValue → underlying` rename per `ascii-primitives-rawvalue-underlying-rename.md` lands in the same commit.

### Shape (b) — `typealias ASCII.Code = Tagged<ASCII, Byte>` + protocol-abstraction technique

```swift
extension ASCII {
    public typealias Code = Tagged<ASCII, Byte>
}

// Byte.Protocol conformance picked up RECURSIVELY via the existing extension in
// swift-byte-primitives/Sources/Byte Primitives/Tagged+Byte.Protocol.swift:
//
//   extension Tagged: Byte.`Protocol`
//   where Underlying: Byte.`Protocol`, Tag: ~Copyable { ... }
//
// Because Byte: Byte.Protocol, Tagged<ASCII, Byte> automatically conforms.

// Classification, constants, parsing attach via constrained extensions on
// Tagged — mirroring Memory.Address's pattern:

extension Tagged where Tag == ASCII, Underlying == Byte {

    // Classification (mirrors current ASCII.Byte+Classification.swift)
    @_transparent
    public var isLetter: Bool { ASCII.Classification.isLetter(underlying.underlying) }
    // ... 11 more classification methods

    // Constants (mirrors current ASCII.Byte+Constants.swift)
    public static var A: UInt8 { ASCII.Character.Graphic.A }
    // ... ~90 more constants

    // Parsing (mirrors current ASCII.Byte+Parsing.swift)
    @inlinable
    public var digitValue: UInt8? { ASCII.Parsing.digit(underlying.underlying) }
    @inlinable
    public var hexValue: UInt8? { ASCII.Parsing.hexDigit(underlying.underlying) }
}
```

**Storage**: `Tagged<ASCII, Byte>` — a Tagged wrapper around a `Byte` (which itself wraps `UInt8`). Per Tagged's universal Carrier conformance, `ASCII.Code.Underlying == Byte`; the raw `UInt8` is reached via `code.underlying.underlying`.

**Migration**: replace the hand-rolled struct with the typealias; rename `ASCII.Byte+*.swift` → `ASCII.Code+*.swift`; rewrite the extension headers from `extension ASCII.Byte { … }` to `extension Tagged where Tag == ASCII, Underlying == Byte { … }`; rewrite `rawValue` internal reads as `underlying.underlying`. The `rawValue → underlying` rename per `ascii-primitives-rawvalue-underlying-rename.md` becomes moot — Tagged uses `underlying` already.

### Shape (c) — Standalone `struct ASCII.Code` wrapping `Byte` (not `UInt8`) + Byte.Protocol conformance

```swift
extension ASCII {
    public struct Code: Sendable {
        public let underlying: Byte

        @inlinable
        public init(_ underlying: consuming Byte) {
            self.underlying = underlying
        }
    }
}

extension ASCII.Code: Byte.`Protocol` {
    public typealias Domain = Never

    @inlinable
    public var byte: Byte { underlying }

    @inlinable
    public init(_ byte: Byte) {
        self.underlying = byte
    }
}

extension ASCII.Code: Equatable {}
extension ASCII.Code: Hashable {}
extension ASCII.Code: Comparable {}
extension ASCII.Code: ExpressibleByIntegerLiteral {}
```

**Storage**: `Byte` (which itself wraps `UInt8`). Two levels of indirection from the raw `UInt8`.

**Migration**: same as (a) but with `underlying: Byte` instead of `underlying: UInt8`. Internal `rawValue` reads become `underlying.underlying`.

## Trade-Off Analysis

### Tier 1: Semantic Identity

The pivotal question: **what is ASCII.Code's relationship to Byte?**

| Reading | Implies shape |
|---------|---------------|
| ASCII.Code IS-A byte (a UInt8 with byte-domain semantics) | (a) — peer byte-domain conformer alongside Byte |
| ASCII.Code IS-A *tagged* Byte (the ASCII domain's wrapping of Byte) | (b) — Tagged<ASCII, Byte> |
| ASCII.Code IS-A Byte-with-ASCII-semantics-bolted-on | (c) — nominal wrapping of Byte |

Per INCITS 4-1986, ASCII is a 7-bit code (0–127). The standard does not present ASCII as "byte-with-ASCII-tag"; it presents ASCII as its own coding system with codes/code points. **ASCII.Code IS-A code** — that is the specification-mirroring identity per `[API-NAME-003]`.

The next-level question: does the code's "codeness" come from being a wrapper around the institute `Byte` value type (option c), from being a UInt8 with byte-domain semantics (option a), or from being a Tagged-phantom-wrapping of the institute `Byte` (option b)?

Three structural arguments:

1. **`Byte.Protocol`'s own Conformers list (Byte.Protocol.swift:63–66) names ASCII.Code as a sibling-conformer alongside `Byte` itself**, not as a Tagged-wrapping of Byte. The doc-comment reads: "Future byte-domain types (e.g., `ASCII.Code`, `Latin1.Byte`, `UTF8.Code_Unit`) conform here to inherit byte-domain operations without re-implementing per-type." The framing is "ASCII.Code conforms to Byte.Protocol directly," not "ASCII.Code = Tagged<ASCII, Byte> via the recursive conformance."

2. **`Byte` itself is the precedent**. The byte-extraction arc's design intent (preserved at `Byte.swift`:5–13) is that `Byte` is the institute's **byte-domain twin** of `UInt8`. ASCII.Code IS-A peer twin in the byte-domain family — *not* a phantom-tagged wrapping of one specific twin. If `Latin1.Byte` were also `Tagged<Latin1, Byte>` and `UTF8.Code_Unit` were `Tagged<UTF8, Byte>`, the design would be a flat family of phantom-tagged Bytes — but that re-introduces the awkwardness `byte-protocol-capability-marker.md` deliberately avoided: every domain-specific byte type would have to be `Tagged<DomainTag, Byte>`, which collapses domain identity into a phantom tag rather than making the type itself carry the domain meaning.

3. **The phantom-tag use-case is type-safe partitioning of the same conceptual value**. `Tagged<Bytes, Cardinal>` vs `Tagged<Frames, Cardinal>` are both *cardinals* (counts) that the type system separates to prevent confusion between byte-counts and frame-counts. ASCII.Code is not "a byte that happens to be tagged ASCII"; it is "a code in the ASCII coding system, which happens to fit in a byte." The semantic gravity is on "code in ASCII," not on "this byte is in the ASCII namespace."

By this reading, the IS-A is **ASCII.Code IS-A byte-domain conformer of Byte.Protocol** — i.e., shape (a). It is NOT IS-A Tagged-phantom-wrapping (which would be shape b), and it is NOT a wrapper-around-Byte (which would be shape c) — it is the direct conformer in the same way `Byte` itself is the direct conformer.

This tier-1 axis disambiguates between (a) and (b)/(c). The disambiguation between (a) and (c) requires the next tier.

### Tier 2: Adjacent-Type Operational Behavior

The canonical adjacent type is `Byte` itself (`swift-byte-primitives/Sources/Byte Primitives/Byte.swift`:36–46):

```swift
@frozen
public struct Byte {
    public let underlying: UInt8

    @inlinable
    public init(_ underlying: consuming UInt8) {
        self.underlying = underlying
    }
}
```

**Byte wraps `UInt8` directly**, not `Byte` (which would be circular) and not `Tagged<_, UInt8>`. Byte is the direct conformer of `Byte.Protocol`; its underlying storage is the raw stdlib `UInt8`. The byte-extraction arc deliberately chose this shape over `Tagged<Bytes, UInt8>`-like alternatives (see `byte-primitive-extraction-and-domain-naming.md` §"Why not Tagged…").

ASCII.Code is the *next member of the same family*. The byte-protocol-capability-marker doc names it alongside Byte and lists it as the same kind of conformer. The principle of consistency-across-adjacent-types (per `[RES-029]` tier-2 ranking — "operational behavior of adjacent ecosystem types ranks higher than use-site counts in the candidate site itself") says: ASCII.Code should take the same shape as Byte. Byte wraps `UInt8`. ASCII.Code should wrap `UInt8`. That is shape (a).

Shape (c) wraps `Byte` instead — adding a level of indirection that `Byte` itself does not have. This deviation from the adjacent-type pattern needs justification; the deviation's only structural argument is *"ASCII.Code is a Byte-with-ASCII-semantics, so it should carry a Byte"* — but the Byte.Protocol mechanism is precisely what carries the byte-semantics. Storing a `Byte` instead of a `UInt8` adds an unboxing step (`code.underlying.underlying` instead of `code.underlying`) without buying additional structural safety: the Byte.Protocol conformance already exposes byte-domain operations on `ASCII.Code` regardless of whether its storage is `UInt8` or `Byte`.

For tier 2, **shape (a) matches the adjacent-type precedent (Byte wraps UInt8); shape (c) deviates without justification**.

Shape (b) is structurally a *different precedent class* — it matches `Memory.Address = Tagged<Memory, Ordinal>` (typealias-over-Tagged). The adjacent-type comparison is: what are the conformers of Ordinal.Protocol? Per `byte-protocol-capability-marker.md` §1.3:

> Bare `Cardinal` does; `Tagged<Tag, Cardinal>` does (recursively, when `Underlying: Cardinal.Protocol`); `UInt` does not. The stdlib `UInt` is the *Underlying carrier* …, but it does not carry the Cardinal-domain capability bundle.

The analogous statement for Byte.Protocol: bare `Byte` does; `Tagged<Tag, Byte>` does (recursively); `UInt8` does not. Per shape (b), `ASCII.Code = Tagged<ASCII, Byte>` would conform via the recursive `Tagged: Byte.Protocol` extension — exactly mirroring `Index<Element>` and `Memory.Address`.

The structural question between (a) and (b) thus reduces to: **is ASCII.Code semantically "a peer byte-domain type" (a) or "a phantom-tagged byte" (b)?** The Byte.Protocol docs say peer; the Tagged precedent admits but does not mandate phantom-tagged.

### Tier 3: Cost / Migration / Ergonomics / Dependency Surface

This tier engages because shapes (a) and (b) are both structurally defensible (different identity readings, both supported by adjacent-type precedents). Tier 3 is a tiebreaker.

#### Matrix

| Axis | Shape (a) | Shape (b) | Shape (c) |
|------|-----------|-----------|-----------|
| **Storage indirection** | `UInt8` (1 step to raw) | `Tagged<ASCII, Byte>` → `Byte` → `UInt8` (2 steps) | `Byte` → `UInt8` (2 steps) |
| **Byte.Protocol conformance mechanism** | Direct conformance (one-line `: Byte.Protocol` + Domain/byte/init witnesses) | Inherited via recursive `Tagged: Byte.Protocol where Underlying: Byte.Protocol` extension (zero-line) | Direct conformance (one-line + witnesses delegating to inner Byte) |
| **API attachment site** | `extension ASCII.Code { ... }` (direct, reads naturally) | `extension Tagged where Tag == ASCII, Underlying == Byte { ... }` (constrained, ~30-char header per extension block) | `extension ASCII.Code { ... }` (direct) |
| **Memory.Address precedent fit** | Different (Memory.Address IS Tagged; ASCII.Code IS-NOT Tagged) | Direct match (both are concrete typealias-over-Tagged with constrained extensions) | Different |
| **Byte precedent fit** | Direct match (both wrap UInt8 + conform Byte.Protocol directly) | Different (Byte does NOT use Tagged for itself) | Approximate (wraps Byte instead of UInt8 — deviates one level) |
| **Domain associated type ergonomic** | `Domain = Never` (bare ASCII.Code is unscoped) | `Domain = ASCII` (automatic from Tagged conformance — Tag IS Domain) | `Domain = Never` |
| **Tagged-recursive composition (`Tagged<X, ASCII.Code>`)** | Available via the same recursive Byte.Protocol extension — phantom-tagged ASCII codes naturally form `Tagged<X, ASCII.Code>` | Available BUT requires `Tagged<X, Tagged<ASCII, Byte>>` — double Tagged. The protocol-abstraction doc §Constraints §"No deep lifting" notes this case explicitly: "The pattern lifts operations one level (Cardinal ↔ Tagged). It does not compose: `Tagged<Tag, Tagged<Tag2, Cardinal>>` would require a separate conformance. This is not needed in practice." | Available via the same recursive Byte.Protocol extension |
| **rawValue → underlying rename** | Lands in same commit (mechanical) | Moot — Tagged uses `underlying` already | Lands in same commit (mechanical) |
| **Internal call-site rewrites** | `rawValue` → `underlying` (~12 internal call sites in Classification/Constants/Parsing extensions) | `rawValue` → `underlying.underlying` (same ~12 sites, slightly longer expression) | `rawValue` → `underlying.underlying` (same) |
| **Dependency on swift-byte-primitives** | Required (for Byte.Protocol) | Required (for Byte + Byte.Protocol + Tagged) | Required (for Byte + Byte.Protocol) |
| **Transitive deps added to swift-ascii-primitives** | swift-carrier-primitives + swift-tagged-primitives + swift-byte-primitives (3 packages) | Same | Same |
| **External consumer impact (36 const + 1 rawValue + 283 ephemeral sites)** | 36 const accesses: type changes name only, value type UInt8 unchanged. 1 rawValue access in foundations/swift-ascii: rename rawValue → underlying. 283 ephemeral .ascii.X: return type renames. | 36 const: same. 1 rawValue: rawValue → underlying.underlying. 283 ephemeral: return type renames (now Tagged<ASCII, Byte>, which is verbose at non-typealias-aware sites). | 36 const: same. 1 rawValue: rename to underlying.underlying. 283 ephemeral: return type renames. |
| **DocC / hover signature** | `struct ASCII.Code` | `Tagged<ASCII, Byte>` (the typealias shows the underlying type at most hover sites) | `struct ASCII.Code` |
| **Discoverability via Xcode jump-to-definition** | Lands on `ASCII.Code` struct decl | Lands on `Tagged` decl (then must trace through typealias chain to find the where-constrained extensions) | Lands on `ASCII.Code` struct decl |

#### Three judgment calls

1. **Storage indirection**. Shape (a) is one step from raw `UInt8`; shapes (b) and (c) are two steps. The institute prefers single-level wrapping (per the Byte precedent — Byte wraps UInt8 directly, not Carrier<UInt8>). For a value type that lives at the byte level of the stack, the extra step adds no semantic value and pays an inlining cost the optimizer can defeat but the source reads as `code.underlying.underlying` which is awkward.

2. **API attachment-site readability**. Shape (a)'s `extension ASCII.Code { ... }` reads as "this is API on ASCII.Code." Shape (b)'s `extension Tagged where Tag == ASCII, Underlying == Byte { ... }` reads as "this is API on a constrained subset of Tagged values" — accurate but indirect. The Memory.Address precedent shows this is workable, but the question is whether it's the *best* shape for ASCII.Code, not whether it's *possible*.

3. **Future composition: `Tagged<X, ASCII.Code>`**. A consumer wanting a phantom-tagged ASCII code (e.g., `Tagged<ParserContext, ASCII.Code>` to distinguish ASCII codes coming from different parser inputs) writes:
   - Under (a): `Tagged<ParserContext, ASCII.Code>` — natural, picks up Byte.Protocol via the recursive extension since `ASCII.Code: Byte.Protocol`.
   - Under (b): `Tagged<ParserContext, Tagged<ASCII, Byte>>` — nested Tagged, which the protocol-abstraction doc explicitly notes is NOT supported by the recursive conformance pattern. This is a real future-composition wart.

The `Tagged<X, ASCII.Code>` composition case (3) is the most decisive of the tier-3 axes. Shape (a) admits future phantom-tagging without re-deriving the recursive-conformance pattern; shape (b) would require workarounds (e.g., flattening to `Tagged<(ParserContext, ASCII), Byte>` with a composite tag) that the ecosystem has not yet codified.

## Recommendation

**RECOMMEND Shape (a)** — standalone `struct ASCII.Code` wrapping `UInt8` + one-line `Byte.Protocol` conformance with the `rawValue → underlying` rename folded into the same commit.

The rationale stacks at three tiers:

### Tier 1 (semantic identity, dispositive)

The `Byte.Protocol` Conformers section (Byte.Protocol.swift:63–66 and byte-protocol-capability-marker.md §"Conformers") names ASCII.Code as a peer byte-domain conformer alongside Byte itself, parallel to future Latin1.Byte / UTF8.Code_Unit / RFC-specific byte types. The semantic identity is "ASCII.Code is a byte-domain type that conforms to Byte.Protocol directly" — not "ASCII.Code is a Tagged-phantom-wrapping of Byte" (shape b) and not "ASCII.Code is a wrapper-around-Byte" (shape c). The specification-mirroring identity (INCITS 4-1986 "code" / "code point") does not encode a phantom-tag relationship; it encodes a peer coding system whose values fit in a byte.

### Tier 2 (adjacent-type operational behavior, confirmatory)

Byte itself (the canonical adjacent type) is a standalone struct wrapping `UInt8` with direct Byte.Protocol conformance. ASCII.Code is the next member of the same family; consistency-across-adjacent-types says it should take the same shape. Shape (a) takes the same shape. Shape (b) takes a different shape (matching `Memory.Address = Tagged<Memory, Ordinal>` instead); shape (c) takes yet another shape (matching nothing in the ecosystem).

### Tier 3 (tiebreakers among structurally-defensible options)

Both (a) and (b) survive tier-1 + tier-2 as plausible-on-some-reading. Tier 3 disambiguates on:

- **Storage indirection**: shape (a) is one step from raw UInt8; shape (b) is two steps. Lower indirection is preferred for byte-level value types where the optimizer's inlining must work to defeat the abstraction cost.

- **API attachment-site readability**: `extension ASCII.Code { ... }` reads as the API on ASCII.Code; `extension Tagged where Tag == ASCII, Underlying == Byte { ... }` is workable (Memory.Address precedent) but less direct.

- **Future Tagged composition**: `Tagged<X, ASCII.Code>` works naturally under shape (a) (picks up Byte.Protocol via the recursive `Tagged: Byte.Protocol where Underlying: Byte.Protocol` extension); under shape (b), the same composition requires `Tagged<X, Tagged<ASCII, Byte>>` which the protocol-abstraction doc §"No deep lifting" explicitly does NOT support without per-case extensions.

### Tier 3 — what shape (a) sacrifices

Shape (a) does NOT inherit Tagged's universal stdlib-conformances (Equatable / Hashable / Comparable / Sendable / ExpressibleByIntegerLiteral) automatically. The conformances must be declared explicitly on `ASCII.Code` (one-line each), and the witnesses come from Byte.Protocol's default-impl extension. This is mechanical and matches the Byte precedent — Byte itself declares the stdlib conformances explicitly. The "automatic via Tagged" benefit of shape (b) is real but small: 4 one-line conformance declarations vs zero. The future-composition cost (Tagged-of-Tagged not supported) decisively dominates.

### Shape (c) rejection summary

Shape (c) (wrap `Byte` instead of `UInt8`) loses on every axis:
- Tier 1: same conformer identity as (a) but indirect storage. No identity reading prefers (c) over (a).
- Tier 2: deviates from Byte's adjacent-type pattern (Byte wraps UInt8, not Carrier<UInt8>).
- Tier 3: same indirection cost as (b), no compensating Tagged-composition benefit.

No reading recommends (c) over (a). Shape (c) is enumerated for completeness per `[RES-009]` but is dominated.

## Implementation Notes

The architectural consequences of adopting shape (a) extend beyond the per-file rename + reshape sketched in the Migration section. Four points the implementation arc MUST own explicitly:

### 1. Tier transition — swift-ascii-primitives moves from Tier 0 to Tier 2

swift-ascii-primitives currently sits in the institute's Tier 0 list (zero primitive dependencies — 21-package cohort per `[PRIM-ARCH-001]`). Adopting `Byte.Protocol` requires `.package(path: "../swift-byte-primitives")`, which transitively pulls `swift-carrier-primitives` (Tier 0) and `swift-tagged-primitives` (Tier 0). swift-byte-primitives itself is Tier 1 (depends on carrier + tagged). Per the tier-computation rule `tier = max(tier[dep] for dep in dependencies) + 1`, swift-ascii-primitives transitions Tier 0 → Tier 2.

This is a real architectural shift in the package's position on the tier DAG, not an incidental side effect of the rename. The package moves from "atomic, no primitive deps" to "depends on the byte-domain capability-marker foundation." The shift is the cost of joining the Byte.Protocol family — the same cost every future per-domain conformer pays.

### 2. `[PRIM-ARCH-001]` Tier 0 list regenerates on implementation-arc landing

The primitives skill `[PRIM-ARCH-001]` Tier 0 list at `swift-institute/Skills/primitives/SKILL.md:188` currently enumerates `swift-ascii-primitives` (line 194) as one of the 21 Tier 0 packages. When the implementation arc lands, that list regenerates with `swift-ascii-primitives` removed from Tier 0; the same package re-appears in the (implicit) Tier 2 cohort after regeneration. Per the existing note at SKILL.md:216, the Tier 0 list is regenerated from `Scripts/compute-tiers.sh` against the live ecosystem state, not amended in place — the implementation arc updates the list by re-running the script and committing its output.

This research arc does NOT touch the skill file. The skill regeneration is the implementation arc's work; flagged here so the implementation arc's scope is unambiguous.

### 3. No dependency cycle — verified by Package.swift grep across the three new transitive deps

The new dependency edges introduced by shape (a) are: swift-ascii-primitives → swift-byte-primitives, with transitive edges to swift-carrier-primitives and swift-tagged-primitives. For the dep-graph to remain acyclic, none of these three packages may reference swift-ascii-primitives. The orchestrator verified this pre-dispatch via Package.swift grep across all three packages: zero references to `swift-ascii-primitives` in any of their Package.swifts. The new dependency edges are structurally safe — no cycle is introduced. This is load-bearing evidence that the tier transition can land mechanically without forcing a topology repair elsewhere.

### 4. Precedent for future per-domain Byte.Protocol conformers

`byte-protocol-capability-marker.md` v1.1.0 §"Conformers" names `Latin1.Byte`, `UTF8.Code_Unit`, and RFC-specific byte types as expected future byte-domain conformers following the same per-domain manual recipe. Each such conformer will pull its host package up by at least two tiers if the host was previously Tier 0 — the same Tier 0 → Tier 2 transition pattern that swift-ascii-primitives undergoes here. The ASCII.Code arc is the first instance and therefore establishes the precedent + the mechanical pattern; every subsequent conformer is a mirror application of the same pattern (add swift-byte-primitives dep, declare `: Byte.Protocol` conformance with the three-line witness set, conform stdlib basics, retire any per-package `rawValue → underlying` rename in the same commit). The tier-shift cost compounds across the byte-domain conformer family; this is the right-cost path because the capability-marker abstraction is the right structural mechanism, but the cumulative tier-DAG impact across the family is a real architectural pattern, not an isolated event.

## Migration Sketch

Shape (a) implementation arc, assuming principal authorization. **Not executed by this advisory document.**

### Step 1 — Add swift-byte-primitives dependency

`swift-ascii-primitives/Package.swift`:

```swift
dependencies: [
    .package(path: "../swift-byte-primitives"),
],
targets: [
    .target(
        name: "ASCII Primitives",
        dependencies: [
            .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        ]
    ),
],
```

This pulls swift-carrier-primitives + swift-tagged-primitives transitively. swift-ascii-primitives moves from zero-dep Tier 0 to a small-fan-in tier with three direct/transitive deps. This is the cost of joining the Byte.Protocol family — same cost paid by every future byte-domain type.

### Step 2 — Rename + reshape `ASCII.Byte → ASCII.Code`

In `swift-ascii-primitives/Sources/ASCII Primitives/`:

- `ASCII.Byte.swift` → `ASCII.Code.swift`. Contents:

  ```swift
  public import Byte_Primitives

  extension ASCII {
      /// A single code point in the ASCII (INCITS 4-1986) coding system.
      @frozen
      public struct Code: Sendable {
          /// The underlying 7-bit code value stored in a UInt8.
          public let underlying: UInt8

          @inlinable
          public init(_ underlying: consuming UInt8) {
              self.underlying = underlying
          }
      }
  }

  // Byte.Protocol conformance — sibling-to-Carrier capability marker per
  // byte-protocol-capability-marker.md.
  extension ASCII.Code: Byte.`Protocol` {
      public typealias Domain = Never

      @inlinable
      public var byte: Byte { Byte(underlying) }

      @inlinable
      public init(_ byte: Byte) {
          self.underlying = byte.underlying
      }
  }

  // Stdlib conformances — witnesses provided by Byte.Protocol default-impl
  // extension (zero/max, ==, hash(into:), <, init(integerLiteral:)).
  extension ASCII.Code: Equatable {}
  extension ASCII.Code: Hashable {}
  extension ASCII.Code: Comparable {}
  extension ASCII.Code: ExpressibleByIntegerLiteral {}
  ```

- `ASCII.Byte+Classification.swift` → `ASCII.Code+Classification.swift`: rename `extension ASCII.Byte` → `extension ASCII.Code`; replace `rawValue` reads with `underlying` (12 sites within this file).

- `ASCII.Byte+Constants.swift` → `ASCII.Code+Constants.swift`: rename `extension ASCII.Byte` → `extension ASCII.Code` (no internal `rawValue` reads — constants return `UInt8` via `ASCII.Character.Control.*` / `ASCII.Character.Graphic.*` / `ASCII.SPACE.sp` accessors).

- `ASCII.Byte+Parsing.swift` → `ASCII.Code+Parsing.swift`: rename `extension ASCII.Byte` → `extension ASCII.Code`; replace `rawValue` reads with `underlying` (2 sites).

The `rawValue → underlying` rename per `ascii-primitives-rawvalue-underlying-rename.md` is **retired in this same commit** — the stored property is now `public let underlying: UInt8`, matching the Byte.Protocol-canonical shape.

### Step 3 — Update the single consumer with a typed reference

`swift-foundations/swift-ascii/.../ASCII.Byte+INCITS_4_1986.swift` is the only file outside swift-ascii-primitives that uses `ASCII.Byte` as a typed value (and reads its `rawValue`). Rename file → `ASCII.Code+INCITS_4_1986.swift`; rename `extension ASCII.Byte` → `extension ASCII.Code`; replace `rawValue` reads with `underlying`.

### Step 4 — Mechanical consumer renames

- 36 `ASCII.Byte.<const>` static accesses in 4 files in swift-terminal-primitives: mechanical `ASCII.Byte → ASCII.Code` rename. The returned constants remain typed `UInt8`; consumer comparison patterns (`byte == ASCII.Byte.esc`) become `byte == ASCII.Code.esc` with no other changes. The constants list (sp, esc, etc.) is preserved verbatim.

- 283 ephemeral `.ascii.X` accessor call sites across the ecosystem: keep the accessor path; the return type's name changes from `ASCII.Byte` to `ASCII.Code` but the call sites do not reference the type explicitly (they consume the value immediately). These sites need ZERO source changes — they recompile against the renamed type automatically.

### Step 5 — DocC / inline-doc refresh

Update `ASCII Primitives.docc` references from `ASCII.Byte` to `ASCII.Code`; refresh symbol-graph links. The DocC catalog already exists and is small.

### Step 6 — Single-package build + ecosystem build verification

Build swift-ascii-primitives (this becomes Tier 1+ after the dep addition; verify SwiftPM resolves cleanly). Build the four consumer packages (swift-terminal-primitives, swift-foundations/swift-ascii, plus the ephemeral-accessor consumers — swift-json, the standards stack, etc.) to confirm zero unintended breakage. The 283 ephemeral-accessor sites are the noise-canary: any of them breaking would indicate the accessor's return type changed beyond just-the-name.

### Step 7 — Deferred rename retirement

`ascii-primitives-rawvalue-underlying-rename.md` (the per-package doc dated 2026-05-03) becomes implemented-and-retired in the same commit set. Mark the doc as IMPLEMENTED with the commit SHA of the rename+reshape; the doc's Q1 ("rawValue → underlying rename, currently no-op pending umbrella migration") closes.

## Open Questions / Follow-ups

### 1. Latin1.Byte / UTF8.Code_Unit — recipe-reuse confirmation

If shape (a) is authorized, the same recipe applies to future Latin1.Byte and UTF8.Code_Unit (`byte-protocol-capability-marker.md` names them as expected conformers). No additional research arc is needed; the per-domain manual recipe IS the answer per Q2 of the capability-marker doc. **Status**: handled by the existing recipe; no follow-up research needed.

### 2. Constants typing — UInt8 vs ASCII.Code

The 90+ static constants on `ASCII.Byte` (e.g., `static var A: UInt8`, `static var esc: UInt8`) currently return raw `UInt8` — deliberately, for ergonomic comparison against `Collection<UInt8>` buffers in terminal-primitives. If shape (a) lands, the same constants on `ASCII.Code` could:
- (i) keep returning `UInt8` (zero consumer impact at the 36 const sites)
- (ii) return `ASCII.Code` (typed at the byte-domain layer)
- (iii) return both via paired accessors

The current pattern picks (i). This research does NOT propose changing the constants' return type; the question is **out of scope for the structural-shape decision** and can be revisited if the typed-constant ergonomics need re-evaluation in a separate code-surface pass. **Status**: status quo (UInt8 constants) preserved; revisit if needed.

### 3. hexValue / digitValue compound-name debt

`ascii-primitives-rawvalue-underlying-rename.md` Q4 flagged `hexValue` and `digitValue` as `[API-NAME-002]`-compound-name violations: candidate for `code.hex.value` / `code.digit.value` nest-and-accessor refactor. **Out of scope for this arc** — flagged for a future code-surface pass. The structural-shape decision does not change the nest-and-accessor decision.

### 4. Skill-rule promotion follow-up

`byte-protocol-capability-marker.md` Q2(b) recommended promoting the per-domain manual recipe to a skill rule (proposed `[API-NAME-001c]` Per-Domain Capability-Marker Protocol). This research uses the recipe; its successful application to ASCII.Code strengthens the case for skill-rule promotion but does NOT itself promote (skill-promotion is a separate workflow). **Status**: defer to skill-lifecycle workflow.

## Constraints Honored

| Constraint | How honored |
|------------|-------------|
| `[PRIM-FOUND-001]` (no Foundation in L1) | None of the three shapes import Foundation. Recommendation preserves Foundation-freedom. |
| `[API-NAME-001c]` (capability-marker recipe; sibling form, per-domain manual) | Shape (a) instantiates the canonical recipe (struct + Byte.Protocol conformance with byte: Byte / init(_: Byte) witnesses). |
| `[API-NAME-003]` (specification-mirroring) | Naming pre-cemented to `ASCII.Code` per INCITS 4-1986 "code" / "code point" terminology. |
| `[MOD-DOMAIN]` (targets represent coherent semantic domains) | ASCII.Code lives in `ASCII Primitives` (swift-ascii-primitives) — the same coherent ASCII domain as the rest of the package. |
| `[RES-018]` case (a) (cross-cutting primitive proposals) | Not applicable. This is case (b) — domain-owned vocabulary at L1; no second-consumer test required. |
| `[HANDOFF-013]` / `[HANDOFF-013a]` (cite prior research) | All five prior-art docs cited above. |
| `[HANDOFF-050]` (workspace-wide grep for consumer enumeration) | Prior subagent executed the grep; this doc cites the findings (36+1+283). |
| `[RES-022]` (Recommendation-Section Framing Heuristic — structural correctness first) | Tier-1 / Tier-2 / Tier-3 priority structure applied; structural correctness disambiguated first; cost/migration applied only as tier-3 tiebreaker. |
| `[RES-029]` (Framing-Challenge for Binding/Membership/Placement Questions) | Question reframed as IS-A identity question before evaluating cost axes. |

## References

### Internal — Authoritative

- [`swift-institute/Research/byte-protocol-capability-marker.md`](./byte-protocol-capability-marker.md) v1.1.0 (Tier 3 RECOMMENDATION, 2026-05-15) — names ASCII.Code as expected per-domain Byte.Protocol conformer; §1.2.1 recursion-vs-refinement constraint.
- [`swift-institute/Research/byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md) v1.0.1 (Tier 2 DECISION, 2026-05-15) — cements Byte.Protocol; identifies the byte-domain conformer family.
- [`swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md`](./protocol-abstraction-for-phantom-typed-wrappers.md) v1.4.0 (Tier 3 DECISION/IMPLEMENTED, 2026-02-13) — canonical per-type X.Protocol recipe; rejected unified-protocol Option I; §"No deep lifting" notes nested-Tagged limitation relevant to shape (b)'s viability.
- [`swift-primitives/swift-ascii-primitives/Research/ascii-primitives-rawvalue-underlying-rename.md`](../../swift-primitives/swift-ascii-primitives/Research/ascii-primitives-rawvalue-underlying-rename.md) (2026-05-03) — pre-authorizes the rawValue → underlying rename, folded into this arc's commit.

### Source files (verified inline documentation and shape)

- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.swift):36–46 — canonical adjacent-type precedent: `struct Byte` wraps `UInt8` directly.
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol.swift):63–66 — Conformers doc-comment names ASCII.Code as expected peer conformer.
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Tagged+Byte.Protocol.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Tagged+Byte.Protocol.swift):27–47 — recursive Tagged conformance enabling shape (b); cited as available-but-not-required.
- [`swift-primitives/swift-memory-primitives/Sources/Memory Primitives Core/Memory.Address.swift`](../../swift-primitives/swift-memory-primitives/Sources/Memory%20Primitives%20Core/Memory.Address.swift):54–193 — typealias-over-Tagged precedent for shape (b)'s pattern: `Memory.Address = Tagged<Memory, Ordinal>` with constrained extensions.
- [`swift-primitives/swift-index-primitives/Sources/Index Primitives Core/Index.swift`](../../swift-primitives/swift-index-primitives/Sources/Index%20Primitives%20Core/Index.swift):38 — generic typealias-over-Tagged precedent: `Index<Element> = Tagged<Element, Ordinal>`.
- [`swift-primitives/swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Byte.swift`](../../swift-primitives/swift-ascii-primitives/Sources/ASCII%20Primitives/ASCII.Byte.swift):24–31 — current ASCII.Byte shape (target of the rename + reshape).

### Skill Rules

- `[API-NAME-001]` Nest.Name Pattern — code-surface SKILL.md.
- `[API-NAME-001c]` Per-Domain Capability-Marker Protocol — proposed (per `byte-protocol-capability-marker.md` Q2(b)); placement TBD.
- `[API-NAME-003]` Specification-Mirroring Names — code-surface SKILL.md (naming origin).
- `[MOD-DOMAIN]` Targets Represent Coherent Semantic Domains — modularization SKILL.md.
- `[PRIM-FOUND-001]` No Foundation in Primitives — primitives SKILL.md.
- `[RES-018]` Premature Cross-Cutting Primitive Anti-Pattern — research-process SKILL.md (case (b) carve-out applies; not gated).
- `[RES-022]` Recommendation-Section Framing Heuristic — research-process SKILL.md.
- `[RES-029]` Framing-Challenge for Binding/Membership/Placement Questions — research-process SKILL.md.
- `[HANDOFF-013]` / `[HANDOFF-013a]` Prior Research Check — handoff SKILL.md.
- `[HANDOFF-050]` Workspace-Wide Grep for Consumer Enumeration — handoff SKILL.md.

## Changelog

- **v1.0.0** (2026-05-16) — Initial Tier 2 RECOMMENDATION discharging the structural-shape question for ASCII.Code (the renamed ASCII.Byte). Three shapes evaluated:
  - (a) standalone `struct ASCII.Code` wrapping `UInt8` + Byte.Protocol conformance — **RECOMMENDED**.
  - (b) `typealias ASCII.Code = Tagged<ASCII, Byte>` — defensible by Memory.Address precedent, rejected on tier-2 (Byte adjacent-type precedent prefers direct struct) and tier-3 (storage indirection + nested-Tagged future-composition wart).
  - (c) standalone `struct ASCII.Code` wrapping `Byte` — dominated by (a) on all axes.

  Naming (`ASCII.Code` per INCITS 4-1986 / `[API-NAME-003]`) is settled pre-research per principal directive; this document does not re-litigate naming. The `rawValue → underlying` rename (per `ascii-primitives-rawvalue-underlying-rename.md`) folds into the same commit if (a) or (c) wins; moot if (b) wins. With (a) recommended, the rename retires implemented.

  Default mode advisory; principal authorizes implementation separately.
</content>
</invoke>