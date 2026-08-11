# ASCII Typed Constants Design — Self-Resolving Across UInt8 Carriers

<!--
---
version: 1.0.0
last_updated: 2026-05-19
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
applies_to:
  - swift-ascii-primitives
  - swift-byte-primitives
  - swift-carrier-primitives
  - swift-foundations/swift-ascii
  - swift-terminal-primitives
  - every-byte-domain-consumer
normative: true
depends_on:
  - swift-institute/Research/byte-protocol-capability-marker.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
  - swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md
  - swift-institute/Research/ascii-code-structural-shape.md
  - swift-institute/Research/ascii-parsing-domain-ownership.md
  - swift-byte-primitives/Research/bsli-gap-inventory.md
  - HANDOFF-byte-adoption-substrate-and-sli.md (parent arc Findings)
---
-->

## Context

The byte-adoption arc (`HANDOFF-byte-adoption-substrate-and-sli.md`,
closed 2026-05-19) migrated the byte-domain ecosystem from `UInt8`
substrate to `Byte` substrate and landed an **interim** ASCII byte-value
namespace using a generic enum wrapper:

```swift
@frozen public enum ASCII.Namespace<Owner: Carrier.`Protocol`>
where Owner.Underlying == UInt8 {}

extension ASCII.Namespace {
    @inlinable public static var space: Owner { Owner(0x20 as UInt8) }
    // … 128 statics
}

extension Carrier.`Protocol` where Underlying == UInt8 {
    @inlinable public static var ascii: ASCII.Namespace<Self>.Type {
        ASCII.Namespace<Self>.self
    }
}
```

This gives every `Carrier.Protocol<UInt8>` conformer — `UInt8` (trivial
self-carrier), `Byte`, `ASCII.Code`, recursive `Tagged<Tag, T>` for
those, and future byte-domain newtypes — a Self-typed `.ascii.X`
accessor. The arc's Findings section records 992 consumer call sites
adopting this shape.

The principal rejected the interim implementation's **naming**: *"the
Namespace wrapper has no semantic weight; the name tells the reader
nothing."* Other constraints were directed but a dedicated arc was
authorized to resolve the design space rather than inline-patch the
close-out. The mechanism is sound; the **name** and the **canonical
literal placement** are open.

In parallel, `ASCII.Code` (the typed-ASCII-byte struct landed by the
2026-05-16 ASCII.Code structural-shape arc per `ascii-code-structural-shape.md`
v1.0.0 Shape (a)) currently holds **`UInt8`-typed** static constants in
`ASCII.Code+Constants.swift`. These are explicitly marked as back-compat
delegations to `ASCII.Character.Graphic.*` / `ASCII.Character.Control.*`
(the spec-categorized UInt8 literal source-of-truth from INCITS 4-1986
sections 4.1 and 4.3). Principal direction: the back-compat shape
disappears; the evergreen end-state is `ASCII.Code.a: ASCII.Code` —
Self-typed canonical home.

This is a Tier 3 question per `[RES-020]`: the cost-of-error is high
(canonical institute ASCII byte-value layer; timeless lifetime), the
affected surface is ecosystem-wide (every byte-domain consumer; every
future byte-domain newtype), and the decision establishes long-lived
semantic contract.

## Question

Four entangled sub-questions, addressed jointly:

| ID | Question | Audience |
|----|----------|----------|
| Q1 | Which Swift idiom satisfies the constraints for the `.ascii.X` access pattern + cross-carrier Self-resolution? | every byte-domain consumer; every future byte-domain newtype author |
| Q2 | Where is the canonical literal value home — `ASCII.Code`, `ASCII.Character.*`, or a new structure? | `swift-ascii-primitives` maintainer |
| Q3 | Disposition of `ASCII.Character.Graphic` / `ASCII.Character.Control` — keep, migrate, or absorb? | `swift-ascii-primitives` maintainer; consumers of the spec-categorized form |
| Q4 | Consumer migration shape — what per-site rewrite produces the upgrade? | every consumer of the existing UInt8-typed `ASCII.Code.X` constants |

## Constraints (Principal-Directed, Verbatim from the Brief)

| ID | Constraint |
|----|------------|
| K1 | **Canonical home Self-typed on `ASCII.Code`**: `static var a: ASCII.Code`. *"ASCII.Code.a:ASCII.Code is what we'd want."* |
| K2 | **Infix preserved**: `*.ascii.a` at consumer sites. NOT `*.a` (top-level pollution); NOT `Type(.a)` (explicit wrap). *"Usage would be *.ascii.a."* |
| K3 | **Cross-type reach**: works for `UInt8`, `Byte`, `ASCII.Code`, AND future byte-domain newtypes — all `Carrier.Protocol<UInt8>` conformers. |
| K4 | **Evergreen end-state**: do NOT optimize for back-compat. *"we should NOT optimize for backward compatibility. we should optimize for evergreen end-state."* Existing UInt8-typed `ASCII.Code.X` constants are NOT load-bearing; they disappear under the recommendation. |
| K5 | **No top-level static pollution**: `Byte` consumers should NOT get `Byte.a`, `Byte.space` as top-level statics. The `.ascii.` prefix isolates the constants under an explicit naming context. |

These constraints are non-negotiable. The investigation enumerates
mechanisms that satisfy them; mechanisms that violate K1–K5 are
disqualified at Tier 1 / Tier 2 in the ranking below.

## Decision Criteria

Per `[RES-029]` (Framing-Challenge for Binding/Membership/Placement
Questions) and `[RES-022]` (Recommendation-Section Framing Heuristic),
the ranking-axis priority is:

| Tier | Axis | Disqualification rule |
|------|------|----------------------|
| 1 | **Semantic identity** | Preserves *"ASCII.Code IS an ASCII byte; constants are ASCII codepoints"*? Designs where ASCII.Code constants are typed `UInt8` (the back-compat shape) fail this. |
| 2 | **Ergonomics across carrier types** | Consumer-site readability — switch patterns, comparisons, conversions. Each of UInt8 / Byte / ASCII.Code / future newtype must have a coherent access path. Designs that work for one but not the others fail. |
| 3 | **Type-system cleanliness** | No overload-ambiguity, no surprise resolution, no per-type duplication. The `Namespace<Owner>` interim was rejected on this axis (the *name* — the *mechanism* is sound). |
| 4 | **Extensibility** | Future byte-domain newtypes (`Latin1.Byte`, `UTF8.Code_Unit`, RFC-specific byte types) inherit the pattern without per-type plumbing. |
| 5 | **Migration cost** | Bounded; per-site, not per-package-wholesale. NOT a tie-breaker if it conflicts with Tier 1–4. |

## Prior Art

Per `[RES-019]` (internal-first), the internal corpus governs. The
external survey adds context for `[RES-021]` contextualization but is
not the determining factor.

### 1. Internal Prior Art

#### 1.1 Per-Domain Capability-Marker Recipe — `byte-protocol-capability-marker.md` v1.1.0

The Tier 3 RECOMMENDATION (2026-05-15) discharging the byte-extraction
arc's open questions. Two findings are load-bearing for this arc:

- **Q1 closure** (UInt8 non-conformance to Byte.Protocol): UInt8 is the
  arithmetic-algebras carrier; Byte (and ASCII.Code, Latin1.Byte,
  UTF8.Code_Unit, …) are byte-domain twins. The byte-vs-arithmetic
  identity separation is preserved by **not** conforming UInt8 to
  Byte.Protocol. The institute's discipline: per-domain capability
  markers exclude the stdlib raw type.

- **Q2 closure** (per-domain X.Protocol IS the canonical pattern; meta-
  protocols / generator macros declined): each byte-domain type follows
  the sibling-form recipe. The recipe is ~20 lines per domain and the
  per-domain choices (which stdlib basics; sibling vs refinement; what
  default impls to provide) should be visible at the use site, not
  hidden in macro expansion. `[IMPL-102]` blocks meta-protocols
  structurally.

**Implication for this arc**: the same separation applies to ASCII
*constants*. ASCII.Code constants are ASCII.Code-typed (per K1 / Tier 1).
The cross-carrier `.ascii.X` shape is a separate question from the
canonical-source question. The brief's scope decision — extension on
`Carrier.Protocol<UInt8>`, not `Byte.Protocol` — is **correct** under
the byte-protocol-capability-marker discipline: constants are value
lookups (which UInt8 can legitimately participate in via its carrier
identity), not behavioral additions (which Byte.Protocol owns).
`Carrier.Protocol+ASCII.swift`:23–32 already documents this rationale.

#### 1.2 The Per-Type X.Protocol Pattern Is Decided — `protocol-abstraction-for-phantom-typed-wrappers.md` v1.4.0

The Tier 3 DECISION / IMPLEMENTED doc establishing per-type `X.Protocol`
as the canonical mechanism for abstracting over bare-vs-Tagged operator
pairs. The doc rejected unified-protocol alternatives (`Taggable<Value>`,
etc.) on the grounds that *"a generic name … trades domain meaning for
generality, and no candidate is satisfactory."* The institute prefers
**domain-meaningful names** over generic structural names.

**Implication for this arc**: the wrapper type's name MUST carry domain
meaning. `Namespace<Owner>` is the generic-structural form the doc
explicitly rejects. A name like `ASCII.Of<Owner>` (function-style; "ASCII
of Owner" = ASCII typed-as-Owner) parallels Swift's idiomatic generic
reading ("Array of Int", "Optional of T") and carries the same semantic
weight as `Cardinal.Protocol` / `Byte.Protocol` for their respective
domains.

#### 1.3 Live-Fire Precedent: Cardinal.Protocol Sibling — `cardinal-protocol-unification-memo.md`

Six-package live-fire precedent for the per-domain capability-marker
recipe. The SUPERSEDED memo (replaced by `cardinal-trivial-self-revert-plan.md`)
records the canonical Cardinal.Protocol sibling shape now in production
across `swift-ordinal-primitives`, `swift-affine-primitives`,
`swift-cyclic-primitives`, `swift-sequence-primitives`,
`swift-finite-primitives`, `swift-bit-vector-primitives`. Net deletion:
~115 lines across all six packages by replacing per-type bare-vs-Tagged
duplication with single-source-of-truth protocol-extension default
impls.

**Implication for this arc**: the institute has empirical evidence that
per-domain X.Protocol + Tagged-recursive conformance + default-impl
extensions IS the working pattern for cross-type code-deduplication. The
ASCII-constants question is structurally adjacent: cross-carrier
Self-typed *value* lookups (vs. cross-carrier behavior lifting). The
solution shape should be congruent.

#### 1.4 ASCII.Code Structural Shape — `ascii-code-structural-shape.md` v1.0.0

The 2026-05-16 Tier 2 RECOMMENDATION that landed Shape (a): standalone
`struct ASCII.Code` wrapping `UInt8` + `Byte.Protocol` conformance via
the sibling-form recipe. This document directly precedes the present
arc. Its §"Verified Inherited State" records the consumer surface at
that time (36 static-constants accesses + 1 rawValue access + 283
ephemeral `.ascii.X` accessor calls); the byte-adoption arc has since
grown that to ~992 `.ascii.X` sites ecosystem-wide.

**Implication for this arc**: the structural-shape decision is settled
(ASCII.Code is standalone; conforms to Byte.Protocol; carries UInt8).
What's open is the *constants* surface — where they live, what type they
return, how they reach across carriers. The recommendation below
operates within the structural shape this prior doc cemented.

#### 1.5 BSLI Gap Inventory — `swift-byte-primitives/Research/bsli-gap-inventory.md`

The 2026-05-19 byte-adoption arc's full friction inventory. Two items
directly bear on this arc:

- **Self-resolving ASCII namespace** (the interim shape): the inventory
  records the supervisor-confirmed `ASCII.Namespace<Owner: Carrier.Protocol>
  where Owner.Underlying == UInt8` as Option IV-a, the form that ships
  today. This arc supersedes the *naming* — the *mechanism* is shared.

- **ASCII-arithmetic ergonomics** (open friction note): sites doing
  ASCII digit decoding (`Int(byte.underlying - 0x30)`) hit friction
  because Byte deliberately has no arithmetic. The resolution involves
  either re-examining the no-arithmetic-on-Byte decision or introducing
  a separate ASCII-digit numeric type. **Out of scope for this arc**;
  the constants question and the arithmetic question are independent.

### 2. External Prior Art ([RES-021])

The brief's external prior art to consult: Swift stdlib patterns,
pointfreeco swift-tagged, Rust crates for typed codepoints, Haskell
typed-Word8 / Char patterns, Apple Foundation typed-constant accessors.

#### 2.1 Swift Stdlib: `Int.max`, `Float.infinity` (Self-Typed Statics)

Swift stdlib pervasively uses Self-typed static constants:
`Int.max: Int`, `Int.min: Int`, `Float.infinity: Float`, `Bool.random()`,
`Double.pi: Double`. Each numeric type declares its own statics
separately on its own type. There is **no cross-carrier Self-resolution
mechanism** — `Int.max` and `UInt.max` are independent declarations on
independent types.

**Why this works for stdlib**: numeric types are concrete and
non-related. The "constants per type" duplication is acceptable because
the type relationships are flat (FixedWidthInteger is a protocol, not a
generic carrier-with-Self-resolution wrapper).

**Why this doesn't transfer cleanly**: the institute's UInt8-carriers
(UInt8, Byte, ASCII.Code, future newtypes) ARE related by Carrier.Protocol
<UInt8>. Per-type duplication would defeat the carrier abstraction and
force every future byte-domain newtype author to copy the 128-constant
table. Fails Tier 4 extensibility.

#### 2.2 pointfreeco swift-tagged: Per-Tagged Constants

`Tagged<Tag, RawValue>` consumers add constants via per-tag constrained
extensions:

```swift
extension Tagged where Tag == UserID, RawValue == Int {
    static var anonymous: Self { Self(rawValue: 0) }
}
```

Each Tagged-variant declares its own constants explicitly. No
cross-Tagged Self-resolution. The institute's `Memory.Address = Tagged<Memory, Ordinal>`
follows the same pattern: ~30 domain-specific affordances attached via
`extension Tagged where Tag == Memory, Underlying == Ordinal { … }`.

**Why this doesn't transfer**: this pattern works when each variant has
*different* constants (UserID's anonymous != ProductID's anonymous). The
institute's ASCII constants are **the same 128 values projected into
different carrier types** — duplication is gratuitous, not load-bearing.

#### 2.3 Rust `unicode-ident` / `unic-char-property`

Rust ASCII / Unicode crates declare constants as module-level functions
operating on raw `u8` / `char`:

```rust
pub fn is_ascii_alphabetic(c: u8) -> bool { … }
```

No newtype wrapping; no cross-carrier abstraction. Rust's design
philosophy embraces raw integer types for byte values; the institute's
philosophy is the opposite (typed byte-domain twin via Byte). The
patterns are not transferrable.

#### 2.4 Haskell `Data.Word.Word8` / `Data.Char.Char`

`Word8` and `Char` are concrete types in their modules. Constants are
module-level values (`maxBound :: Word8`, `chr 65 :: Char`). No
typeclass dispatch over constants; no cross-newtype Self-resolution.
Haskell's typeclass mechanism handles *behavior* lifting (Ord, Eq,
Show), not *value* sharing across newtypes.

#### 2.5 Apple Foundation `Character` / `Unicode.Scalar`

`Unicode.Scalar` is a concrete struct with `init(_ value: UInt32)`
constructors. Constants are typically defined per-consumer (e.g.,
`extension Character { static let separator: Character = "," }`). No
generic cross-type constant wrapper.

#### 2.6 External Survey Verdict

Cross-carrier Self-typed value constants — the exact problem this arc
solves — is **not a common pattern in surveyed systems**. Most languages
either (a) embrace raw integer types (Rust, C), (b) declare constants
per-newtype with explicit duplication (Haskell, Scala, Swift stdlib), or
(c) handle the problem via typeclass-driven *behavior* lifting (Haskell
typeclasses), which is orthogonal to constants.

The institute's challenge — Self-typed constants across multiple
structurally-related newtypes sharing a representational underlying type
— is somewhat novel. The Owner-parameterized empty-enum wrapper is a
**reasonable Swift idiom** for this; it composes the protocol-abstraction
pattern (per-type X.Protocol) with the generic-namespace pattern
(empty-enum-as-type-level-namespace, used pervasively across the
institute).

### 3. Contextualization Step ([RES-021])

Per `[RES-021]`:

> When a prior art survey identifies a pattern that is universally
> adopted across surveyed systems but absent from the ecosystem, the
> survey MUST include a "contextualization step" before classifying the
> absence as a gap.

**Pattern observed**: every surveyed system declares ASCII / character
constants *per-type* — either on a single concrete type (Rust's `u8`
free functions, Haskell's `Char`, Foundation's `Unicode.Scalar`) or
duplicated per newtype (swift-tagged's per-Tag extensions, Memory.Address's
per-Tagged constants).

**Absent from the ecosystem**: cross-newtype Self-resolving constant
sharing.

**Why the absence is deliberate**: the institute's UInt8-carrier family
(UInt8, Byte, ASCII.Code, Latin1.Byte, UTF8.Code_Unit, …) is itself
novel — most ecosystems don't have a 4+ way structurally-related byte
type hierarchy. Per-type duplication of 128 ASCII constants × 4+ types
× growing-over-time = unbounded. The institute's carrier-abstraction
machinery makes cross-carrier Self-resolution mechanically expressible;
not exploiting it would discard the carrier-abstraction value.

The contextualization step confirms: **the institute's design space
includes a pattern surveyed systems lack but the institute's type system
supports**. The Owner-parameterized empty-enum wrapper is the natural
realization.

## Design Space

Per the brief's option enumeration plus open survey:

### Option A — Generic enum wrapper named `Namespace<Owner>` (the interim)

```swift
@frozen public enum ASCII.Namespace<Owner: Carrier.`Protocol`>
where Owner.Underlying == UInt8 {}
extension ASCII.Namespace {
    @inlinable public static var space: Owner { Owner(0x20 as UInt8) }
}
```

**Mechanism**: empty generic enum, Owner-parameterized; 128 static
properties each constructing `Owner(literal as UInt8)`.

**Verdict**: REJECTED — Tier 3 (type-system cleanliness; principal's
naming objection). The mechanism is sound but `Namespace<Owner>` is
generic-structural with no domain meaning. The institute's
`protocol-abstraction-for-phantom-typed-wrappers.md` decision explicitly
rejects generic-structural names in favor of domain-meaningful names.

### Option B — Protocol-extension static subscript

```swift
extension Carrier.`Protocol` where Underlying == UInt8 {
    @inlinable public static subscript(ascii path: KeyPath<ASCII.Code.Type, ASCII.Code>) -> Self {
        Self(ASCII.Code.self[keyPath: path].underlying)
    }
}
// Usage: Byte[ascii: \.a]
```

**Mechanism**: static subscript indexed by a KeyPath into ASCII.Code.

**Verdict**: REJECTED — Tier 2 (ergonomics). The call shape is
`Byte[ascii: \.a]` with brackets and KeyPath literal; this is NOT the
`*.ascii.X` infix preserved per K2. The brief explicitly states the
access pattern is infix dot-access; the subscript shape violates it.

### Option C — Nested helper type with semantic-weight name

```swift
extension ASCII {
    @frozen public enum Of<Owner: Carrier.`Protocol`>
    where Owner.Underlying == UInt8 {}
}
extension ASCII.Of {
    @inlinable public static var space: Owner { Owner(ASCII.Code.space.underlying) }
}
extension Carrier.`Protocol` where Underlying == UInt8 {
    @inlinable public static var ascii: ASCII.Of<Self>.Type { ASCII.Of<Self>.self }
}
```

**Mechanism**: structurally identical to Option A (empty generic enum
+ Owner-parameterized statics + Carrier.Protocol extension accessor),
**renamed** to carry domain meaning. The brief explicitly calls out this
shape: *"Nested helper type under `ASCII.Code` or `ASCII` (e.g., `ASCII.For<Owner>`)
— IF name carries semantic weight unlike 'Namespace'."*

**Naming candidate analysis** — names that carry semantic weight:

| Candidate | Reading | Verdict |
|-----------|---------|---------|
| `ASCII.Of<Owner>` | "ASCII of Byte" — parallels Swift's `Array of Int` generic reading | **PRIMARY** — short, function-style preposition, parallels `Array<T>` / `Optional<T>` / `Result<T, E>` idiomatic reading |
| `ASCII.As<Owner>` | "ASCII as Byte" — type-casting reading | Close alternative; "as" suggests runtime casting which the wrapper doesn't perform |
| `ASCII.For<Owner>` | "ASCII for Byte" — purpose reading | Close alternative; "for" emphasizes target consumer (less precise than "of") |
| `ASCII.Constants<Owner>` | "ASCII constants typed as Byte" — most direct | Verbose; "Constants" is descriptive but adds 9 characters at type-name reading without payoff over "Of" |
| `ASCII.Codepoint<Owner>` | "ASCII codepoint typed as Byte" — spec-aligned | Conflicts conceptually with `ASCII.Code` (which IS the canonical typed codepoint); ambiguity at the maintainer-reading layer |
| `ASCII.Encoded<Owner>` | "ASCII-encoded value of Byte" | Suggests encoding-action (e.g., bytes of an encoded string), not codepoint constants |
| `ASCII.Projection<Owner>` | "ASCII projected to Byte" | Mathematically precise; verbose; "projection" has multiple readings in CS |
| `ASCII.View<Owner>` | "a view of ASCII for Byte" | Conflicts with `Property.View` family and `Span` "view" terminology |

**Selected name**: `ASCII.Of<Owner>`.

Rationale: function-style preposition reads naturally ("ASCII of Byte",
"ASCII of UInt8", "ASCII of ASCII.Code"). Parallels Swift's idiomatic
generic-type reading. Short (avoids verbosity at the wrapper-type level
where the name appears in extension declarations and return types). The
canonical literal home (per K1) is on `ASCII.Code` directly; the wrapper
is the *cross-carrier projection layer*, and "Of" expresses the
projection succinctly. The runner-up is `ASCII.Constants<Owner>` for
maintainers who prefer descriptive over idiomatic; the choice is a
judgment call and either satisfies Tier 3.

**Verdict**: **RECOMMENDED** (with `ASCII.Of<Owner>` as the chosen
name). Tier 1–4 satisfied:

- Tier 1 (semantic identity): canonical home is on `ASCII.Code` (Self-typed);
  wrapper delegates. Preserved.
- Tier 2 (ergonomics): `Byte.ascii.space` infix preserved across all
  Carrier.Protocol<UInt8> conformers. Self-typed return enables `byte == .ascii.space`
  pattern without explicit conversion.
- Tier 3 (cleanliness): renamed from `Namespace` to `Of` removes the
  principal's structural-name objection. Single source of truth (ASCII.Code
  statics); wrapper delegates via `@inlinable`. No overload ambiguity.
- Tier 4 (extensibility): future byte-domain newtypes that conform
  Carrier.Protocol<UInt8> inherit `.ascii.X` automatically with zero
  per-type plumbing.

### Option D — Macros generating per-carrier `ascii` namespace

```swift
@ASCIINamespace
extension Byte { }
// Expands to: per-type ascii enum + 128 statics
```

**Mechanism**: Swift macro generates per-conforming-type duplicates of
the ASCII namespace + 128 statics.

**Verdict**: REJECTED — Tier 3 (cleanliness) + Tier 4 (extensibility).

- Per-type expansion produces N × 128 generated declarations (with N
  growing as new byte-domain newtypes land). Cumulative build cost.
- Macro expansion is opaque. Maintainers reading source must mentally
  expand the macro to know what surface their type exposes.
- The recipe is structurally simple — Option C is ~135 lines (128
  statics + extension declaration + accessor + frontmatter); compressing
  that into a macro buys no information at significant complexity cost.
- Per byte-protocol-capability-marker.md Q2 closure: macros for the
  per-domain X.Protocol recipe were declined for the same reasons
  (recipe simplicity; macro hides per-domain choices). The same
  reasoning applies here.
- Future newtype authors must opt into the macro per type. Friction at
  extensibility (Tier 4 demands zero per-type plumbing).

### Option E — KeyPath-driven `byte[keyPath: ASCII.space]` shape

```swift
extension ASCII {
    public static let space: KeyPath<...> = ...
}
let byte: Byte = .[keyPath: ASCII.space]  // not exactly valid syntax
```

**Mechanism**: KeyPaths as top-level constant identifiers; consumers
apply the KeyPath at the use site.

**Verdict**: REJECTED — Tier 2 (ergonomics) + Tier 3 (cleanliness).

- Doesn't preserve `*.ascii.X` infix per K2. Consumers write
  `byte == [keyPath: ASCII.space]` or similar — bracket-shape, not dot-
  shape.
- KeyPaths require a Root type; the cross-carrier Self-resolution
  problem doesn't fit KeyPath's instance-rooted model cleanly.
- Doesn't compose with future `@dynamicMemberLookup` enhancements
  cleanly (and Swift's static-property KeyPath support is incomplete /
  evolving).

#### Option E' — `@dynamicMemberLookup` with KeyPath subscript (Sub-Variant)

```swift
@dynamicMemberLookup
@frozen public struct ASCII.Lookup<Owner: Carrier.`Protocol`>
where Owner.Underlying == UInt8 {
    public init() {}
    @inlinable public subscript(
        dynamicMember keyPath: KeyPath<ASCII.Code.Type, ASCII.Code>
    ) -> Owner {
        Owner(ASCII.Code.self[keyPath: keyPath].underlying)
    }
}
extension Carrier.`Protocol` where Underlying == UInt8 {
    @inlinable public static var ascii: ASCII.Lookup<Self> { ASCII.Lookup<Self>() }
}
```

**Mechanism**: dynamic member lookup with KeyPath subscript routes
`Byte.ascii.a` through `KeyPath<ASCII.Code.Type, ASCII.Code>` to the
canonical ASCII.Code statics. Avoids the 128-line static-vars duplication
in the wrapper.

**Verdict**: DEFERRED — uncertain Swift mechanics.

- Swift's support for static-property KeyPaths via dynamic member lookup
  is evolving and not yet a robust idiom. The compiler resolves `\Root.X`
  for instance members; metatype-rooted KeyPaths (`\Root.Type.staticVar`)
  have historically had compiler-support gaps that this arc cannot
  empirically verify without spike-testing.
- If empirically verified to work and to optimize at -O (eliding the
  KeyPath through `@inlinable`), this would be a strict improvement over
  Option C (eliminates the wrapper's 128-static-vars duplication).
- Diagnostic quality and IDE autocomplete fidelity for dynamic member
  lookup are degraded vs explicit static properties; the consumer
  surface gains nothing (consumers see `.ascii.X` either way), so the
  gain is purely maintainer-side.

**Recommendation**: not chosen as primary. Could be revisited as an
optimization arc once Swift's static-property KeyPath story stabilizes,
or after empirical spike. The 128-line wrapper cost in Option C is
acceptable for a leaf primitives package; the gain from E' is
non-load-bearing.

### Option F — Phantom-typed enum cases on a single carrier

```swift
public enum ASCII.Symbol {
    case nul, soh, ..., a, b, ..., z, ...   // 128 cases
    public var value: UInt8 { ... }
}
extension Carrier.`Protocol` where Underlying == UInt8 {
    @inlinable public static func ascii(_ s: ASCII.Symbol) -> Self {
        Self(s.value)
    }
}
// Usage: let byte: Byte = .ascii(.a)
```

**Mechanism**: enum representing the 128 codepoints; cross-carrier
factory function takes a case.

**Verdict**: REJECTED — Tier 2 (ergonomics).

- Function-call shape `.ascii(.a)` doesn't preserve `*.ascii.X` infix
  per K2.
- Enum-cases-as-constants is unusual for byte-value mapping (Swift
  idiom is `static var` for value constants; `enum case` for variant
  selection). Conflicts with reader expectation.
- Switch patterns: `case .ascii(.a):` works in switches but requires
  the wrap; less readable than `case .ascii.a:` (which Option C
  produces because static-var members participate in pattern matching
  via Self-comparison).
- Implicit-member shorthand `let byte: Byte = .ascii(.a)` works at
  assignment, but at comparison `byte == .ascii(.a)` reads as a function
  application against the case, less natural than `byte == .ascii.a`.

### Option G — Other Swift patterns (open survey)

Additional shapes considered:

- **G1 — Per-conformer extension declaring its own `ascii` namespace
  enum**: each carrier type gets its own `extension Byte { public enum ascii { … } }`,
  with 128 statics duplicated per type. Fails Tier 4 (extensibility) +
  Tier 3 (per-type duplication; future newtypes must copy).

- **G2 — Top-level ASCII constants typed `ASCII.Code` + per-carrier
  `Type(.ascii.X)` wrap**: `extension ASCII { static var a: ASCII.Code }`
  + every consumer writes `Byte(.ascii.a)`. Violates K2 (explicit wrap
  loses `.ascii.` infix prefix).

- **G3 — `ASCII.Code` as a typealias for `Tagged<ASCII, Byte>` with
  recursive constant lifting**: was Shape (b) in
  `ascii-code-structural-shape.md` v1.0.0; rejected for unrelated reasons
  (storage shape; classification-method placement). Does not change the
  constants question.

- **G4 — Concrete `ASCII.Of<Owner>` struct (not enum) with stored
  Owner-typed constants**: stored properties would consume runtime
  memory per type-instantiation; `@frozen public enum` (empty enum)
  with computed `@inlinable` statics is the zero-cost form.

None of G1–G4 offer Tier 1–5 improvements over Option C; documented for
completeness.

## Recommendation

**Status**: RECOMMENDATION
**Tier**: 3

The following four-part recommendation jointly answers Q1–Q4. The parts
are coherent (each implies the others); changing one requires re-deriving
the rest.

### Verdict 1 (Q1) — Mechanism: Option C with `ASCII.Of<Owner>` naming

The mechanism is the Owner-parameterized empty-enum wrapper, **renamed**
from the interim `ASCII.Namespace<Owner>` to **`ASCII.Of<Owner>`**:

```swift
extension ASCII {
    /// ASCII codepoints projected into a UInt8-carrier type.
    ///
    /// `ASCII.Of<Owner>` is the cross-carrier projection layer: every
    /// `Carrier.\`Protocol\`<UInt8>` conformer (UInt8, Byte, ASCII.Code,
    /// recursive `Tagged<_, T>`, future byte-domain newtypes) reaches
    /// the 128 ASCII codepoints as Self-typed values through this
    /// wrapper. The canonical literal source is on ``ASCII.Code``; this
    /// wrapper delegates per-codepoint.
    @frozen public enum Of<Owner: Carrier.`Protocol`>
    where Owner.Underlying == UInt8 {}
}

extension ASCII.Of {
    @inlinable public static var space: Owner { Owner(ASCII.Code.space.underlying) }
    @inlinable public static var a: Owner { Owner(ASCII.Code.a.underlying) }
    // … 128 delegations, all `@inlinable`
}

extension Carrier.`Protocol` where Underlying == UInt8 {
    /// Type-level access to ASCII codepoints, Self-resolving.
    ///
    /// ```swift
    /// UInt8.ascii.space      // UInt8 (0x20)
    /// Byte.ascii.space       // Byte
    /// ASCII.Code.ascii.space // ASCII.Code
    /// ```
    @inlinable public static var ascii: ASCII.Of<Self>.Type {
        ASCII.Of<Self>.self
    }
}
```

**Per-tier satisfaction**:

| Tier | Axis | Disposition |
|------|------|-------------|
| 1 | Semantic identity | Canonical literal home is `ASCII.Code` (Self-typed); `ASCII.Of<Owner>` is the projection layer. Reader's mental model: *"ASCII.Code IS the codepoint; `ASCII.Of<Owner>` projects it into Owner's type."* |
| 2 | Ergonomics | `*.ascii.X` infix preserved across all carriers. `byte == .ascii.space` (where byte: Byte) compiles cleanly via Self-resolution. Switch patterns work. |
| 3 | Type-system cleanliness | No overload ambiguity (each Carrier.Protocol<UInt8> conformer reaches `ASCII.Of<Self>.X` unambiguously). No per-type duplication of constants. Single source of truth on ASCII.Code. The renaming from `Namespace` to `Of` resolves the principal's structural-name objection — `Of<Owner>` parallels Swift's `Array<T>` / `Optional<T>` / `Result<T, E>` idiom ("F of X = F<X>"). |
| 4 | Extensibility | Future byte-domain newtypes (Latin1.Byte, UTF8.Code_Unit, RFC_3986.URI.Octet, …) that conform `Carrier.Protocol<UInt8>` get `.ascii.X` automatically. Zero per-type plumbing. |
| 5 | Migration cost | Bounded — the ecosystem already adopted `.ascii.X` (992 sites). The migration is internal-source-only: rename `ASCII.Namespace` → `ASCII.Of`; flip ASCII.Code statics from UInt8-typed to ASCII.Code-typed; absorb ASCII.Character.* into ASCII.Code statics. See Migration Plan below. |

### Verdict 2 (Q2) — Canonical Literal Home: `ASCII.Code` Self-Typed

The 128 literal values (`0x00 … 0x7F` minus the gaps from 0x20 SPACE
handling) live as `@inlinable` static computed properties on
`ASCII.Code`, Self-typed:

```swift
// In ASCII.Code+Constants.swift (renamed from current file; UInt8 disappears)
extension ASCII.Code {
    // MARK: - Control Characters (0x00–0x1F, 0x7F)
    @inlinable public static var nul: ASCII.Code { ASCII.Code(0x00) }
    @inlinable public static var lf: ASCII.Code { ASCII.Code(0x0A) }
    // …

    // MARK: - SPACE (0x20)
    @inlinable public static var space: ASCII.Code { ASCII.Code(0x20) }
    @inlinable public static var sp: ASCII.Code { space }

    // MARK: - Graphic Punctuation (0x21–0x2F)
    @inlinable public static var exclamationPoint: ASCII.Code { ASCII.Code(0x21) }
    // …

    // MARK: - Graphic Digits (0x30–0x39)
    @inlinable public static var `0`: ASCII.Code { ASCII.Code(0x30) }
    // …

    // MARK: - Graphic Uppercase Letters (0x41–0x5A)
    @inlinable public static var A: ASCII.Code { ASCII.Code(0x41) }
    // …

    // MARK: - Graphic Lowercase Letters (0x61–0x7A)
    @inlinable public static var a: ASCII.Code { ASCII.Code(0x61) }
    // …
}
```

**Why ASCII.Code, not the generic wrapper, owns the canonical literals**:

- K1 (principal direction): *"ASCII.Code.a:ASCII.Code is what we'd
  want."*
- Tier 1 (semantic identity): ASCII.Code IS the typed-ASCII-byte; the
  literal value of 'a' (codepoint 0x61) is structurally an ASCII.Code,
  not a generic wrapper member.
- Type-system cleanliness: a single source of truth eliminates the
  question *"if I change `space` from 0x20 to (hypothetically) 0xFF
  to fix a bug, where do I edit?"* Answer: ASCII.Code's static-var
  body. The wrapper's delegation `Owner(ASCII.Code.space.underlying)`
  automatically picks up the change.
- Diagnostic quality: type-checker errors reference `ASCII.Code.space`,
  not `ASCII.Of<Byte>.space`, which is the more familiar reading for
  consumers who think of the constants as ASCII.Code properties.

**Naming aliases** (carried forward from the interim shape's
documented aliases for ergonomics):

| Canonical | Aliases | Domain |
|-----------|---------|--------|
| `lf` | `newline` | line-ending convention |
| `htab` | `tab` | tab convention |
| `space` | `sp` | brevity vs descriptive (sp matches ASCII spec tradition) |
| `slant` | `solidus`, `slash`, `forwardSlash` | name variation |
| `reverseSlant` | `reverseSolidus`, `backslash` | name variation |
| `commercialAt` | `at`, `atSign` | name variation |
| `lessThanSign` | `lt`, `lessThan` | brevity |
| `greaterThanSign` | `gt`, `greaterThan` | brevity |
| `quotationMark` | `dquote`, `doubleQuote` | name variation |
| `leftBracket` | `leftSquareBracket` | disambiguation from `leftBrace` |
| `rightBracket` | `rightSquareBracket` | disambiguation from `rightBrace` |

Each alias is a one-line `@inlinable` static var pointing at the
canonical static var (e.g., `@inlinable public static var sp: ASCII.Code { space }`).

### Verdict 3 (Q3) — `ASCII.Character.*` Disposition: ABSORB

`ASCII.Character.Graphic` and `ASCII.Character.Control` (the current
UInt8-typed spec-categorized literal source-of-truth) are **absorbed**
into ASCII.Code's Self-typed statics. The spec categorization persists
through:

1. **MARK-group comments in ASCII.Code+Constants.swift** — preserves
   visual spec-section grouping (Section 4.1 Control / Section 4.3
   Graphic / SPACE per INCITS 4-1986) for source readers.

2. **Existing classification predicates in ASCII.Code+Classification.swift**
   — `isControl`, `isGraphic`, `isLetter`, `isUppercase`, `isLowercase`,
   `isDigit`, etc. These are the *runtime* expression of the spec's
   categorization; they remain unchanged and continue to operate over
   `ASCII.Code` values.

3. **Documentation citations** — INCITS 4-1986 §4.1 and §4.3 cited in
   the relevant MARK-group comments.

**Why absorb rather than keep**:

- K4 (evergreen, no back-compat): the prior shape (ASCII.Character.\*
  as UInt8-typed source-of-truth + ASCII.Code+Constants.swift delegations
  returning UInt8) is a back-compat layer that disappears under the
  recommendation. Keeping ASCII.Character.* as a duplicate
  ASCII.Code-typed source-of-truth would re-introduce the back-compat
  shape under a different name.
- Type-system cleanliness: two-tier source-of-truth (ASCII.Character.*
  AND ASCII.Code.*) doubles the maintenance surface for additions /
  changes. Single source eliminates the risk of drift.
- Spec-mirroring [API-NAME-003]: the spec's categorization survives via
  MARK comments + classification predicates. The category itself
  (Graphic vs Control) is **structural metadata**, not a runtime type.
  Modeling it as a namespace nesting forces a single-categorization
  choice on the constants (Graphic.A vs Control.lf are mutually
  exclusive enum nests), but the spec also says SPACE (0x20) has
  "dual nature as both a graphic and control character" — which the
  current ASCII.SPACE separate namespace acknowledges. Flat statics on
  ASCII.Code with classification predicates is the more faithful
  representation of the spec's actual structure.

**Migration scope for ASCII.Character.* consumers**:

The survey identified 227 ecosystem-wide references to ASCII.Character.*:
- 175 in swift-ascii-primitives (defs + docstrings — internal, migrate
  with the absorption)
- 23 in swift-svg-render
- 12 in swift-glob-primitives
- 12 in swift-tests
- 5 in swift-posix

Migration per call site:
- `ASCII.Character.Graphic.A` → `ASCII.Code.A` (canonical, ASCII.Code-typed)
  OR `.ascii.A` (Self-typed at usage site, when consumer is Carrier.Protocol
  <UInt8>-typed)
- `ASCII.Character.Control.lf` → `ASCII.Code.lf` / `.ascii.lf`
- `ASCII.Character.Control.crlf` (the `[UInt8]` array constant) →
  `ASCII.Code.crlf` returning `[ASCII.Code]`, OR a Sequence-level
  alternative; see Open Follow-ups.

**Variant** — alternative formulations the maintainer may consider:

A weaker form of absorption preserves `ASCII.Character` as a *typealias
group* of computed accessors that mirror ASCII.Code statics by spec
section:

```swift
extension ASCII.Character {
    public enum Graphic {
        @inlinable public static var A: ASCII.Code { ASCII.Code.A }
        // …
    }
    public enum Control {
        @inlinable public static var lf: ASCII.Code { ASCII.Code.lf }
        // …
    }
}
```

This preserves the spec-mirroring access form `ASCII.Character.Graphic.A`
but turns ASCII.Character.* into a delegation layer (the inverse of the
current arrangement: today ASCII.Character.* is source-of-truth and
ASCII.Code delegates; this variant inverts).

**Verdict on the variant**: NOT RECOMMENDED. The variant preserves a
secondary access form whose value (spec-mirroring categorization) is
already preserved via MARK comments and classification predicates. The
cost is permanently doubling the namespace surface, increasing the
"which form do I use?" decision burden on consumers. K4 (evergreen)
favors the absorbed shape; K3 (semantic identity) is preserved either
way; Tier 3 (cleanliness) favors absorption. If empirically the
spec-categorized form has documentation value sufficient to justify
the doubled surface, the maintainer may resurrect the variant; absent
that evidence, absorption is the cleaner end-state.

### Verdict 4 (Q4) — Consumer Migration Shape

Migration is **type-driven**: at each consumer site, the new shape's
type determines the rewrite. The 992 existing `.ascii.X` sites mostly
need no source change — they pick up the new Self-typed values
automatically. The 41 `ASCII.Code.X` direct references (mostly in
swift-terminal-primitives) migrate to `.ascii.X`. The 227 `ASCII.Character.*`
references migrate per the table below.

**Per-site rewrite table**:

| Consumer pattern | Before (UInt8-back-compat shape) | After (evergreen shape) |
|------------------|----------------------------------|--------------------------|
| Type-checked comparison, byte: Byte | `byte == .ascii.space` (Byte == Byte via Namespace<Byte>) | `byte == .ascii.space` — unchanged at source; Self-resolution now goes through `ASCII.Of<Byte>` returning Byte |
| Type-checked comparison, byte: UInt8 | `bytes.contains(ASCII.Code.space)` (ASCII.Code.space: UInt8) | `bytes.contains(.ascii.space)` — `.ascii.space: UInt8` via ASCII.Of<UInt8> |
| Switch case, byte: UInt8 | `case ASCII.Code.A, ASCII.Code.B, ...` | `case .ascii.A, .ascii.B, ...` — `.ascii.A: UInt8` via ASCII.Of<UInt8> |
| Direct access, ASCII.Code-typed | `let c = ASCII.Code(rawValue: 0x41)` | `let c = ASCII.Code.A` (canonical) OR `ASCII.Code.ascii.A` (projection) — both yield ASCII.Code(0x41) |
| Spec-categorized, UInt8-typed | `ASCII.Character.Graphic.A` (returns UInt8) | `ASCII.Code.A` (returns ASCII.Code) OR `.ascii.A` (Self-typed at site); converter to UInt8 if needed: `ASCII.Code.A.underlying` |
| Buffer construction | `buffer.append(ASCII.Character.Graphic.space)` (buffer.Element == UInt8) | `buffer.append(.ascii.space)` — `.ascii.space: UInt8` via ASCII.Of<UInt8> |
| CRLF array | `bytes += ASCII.Character.Control.crlf` (`crlf: [UInt8]`) | `bytes += ASCII.Code.crlf` returning `[ASCII.Code]`, OR rewrite to two separate appends for clarity |

**Scope estimate** (from the ecosystem survey):

| Migration class | Sites | Packages | Disposition |
|-----------------|-------|----------|-------------|
| `.ascii.X` infix (no change needed) | 992 | swift-ascii (577), swift-json (105), swift-html-render (99), swift-lexer-primitives (59), swift-parsers (57), swift-file-system (42), swift-ascii-primitives (33), swift-pdf-render (11), others (9) | No source change; behavior shifts to Self-typed automatically |
| `ASCII.Code.X` direct access | 41 | swift-terminal-primitives (32), swift-ascii-primitives (9) | Rewrite to `.ascii.X`; switch cases need attention |
| `ASCII.Character.Graphic/Control.X` | 227 | swift-ascii-primitives (175 — internal), swift-svg-render (23), swift-glob-primitives (12), swift-tests (12), swift-posix (5) | Rewrite to `.ascii.X` or `ASCII.Code.X` (Self-typed) |
| `ASCII.SPACE.sp` | 4 | swift-ascii-primitives (definitions), swift-svg-render (1 site) | Rewrite to `.ascii.space` or `ASCII.Code.space` |
| `ASCII.whitespaces` (Set<UInt8>) | 4 | swift-ascii-primitives (defs only) | Type may migrate to `Set<ASCII.Code>` or stay as `Set<UInt8>` for stdlib compatibility; see Open Follow-ups |

**Compound migration cost estimate**: ~270 source rewrites across ~9
packages, plus internal source-of-truth changes in swift-ascii-primitives
(~175 lines absorbed from ASCII.Character.* into ASCII.Code). The
ecosystem-wide grep `.retag(Byte.self)|.retag(UInt8.self)` from the
parent byte-adoption arc is the closest precedent — that arc landed in
10 commits across 10 repos with ~400+ sites touched. The ASCII-constants
migration is comparable in shape, scoped narrower (constants only, no
substrate change). Expected execution: 5–8 commits across 4–6
packages.

**Risk**: low. Each rewrite is type-checked locally; failures surface as
compile errors at the call site, not silent semantic changes. The two
distinct migration shapes (UInt8 consumer / Byte-domain consumer) have
local-scope evidence (the consumer's variable type) that determines the
rewrite, eliminating ambiguity.

## Future-Byte-Domain Reach

The recommendation's Tier 4 (extensibility) is structural: future
byte-domain newtypes conforming `Carrier.Protocol<UInt8>` inherit
`.ascii.X` automatically.

### Sketch — `Latin1.Byte` adoption

```swift
// In a future swift-latin1-primitives (analogous to swift-ascii-primitives)
extension Latin1 {
    @frozen public struct Byte: Sendable {
        public let underlying: UInt8
        @inlinable public init(_ underlying: consuming UInt8) {
            self.underlying = underlying
        }
    }
}

extension Latin1.Byte: Carrier.`Protocol` {
    public typealias Underlying = UInt8
    // underlying + init satisfied by stored property + init above
}

extension Latin1.Byte: Byte.`Protocol` {
    public typealias Domain = Never
    @inlinable public var byte: Byte { Byte(underlying) }
    @inlinable public init(_ byte: Byte) { self.init(byte.underlying) }
}

// And THAT'S IT for ASCII support. Latin1.Byte automatically gains:
//   Latin1.Byte.ascii.a       // Latin1.Byte(0x61)
//   Latin1.Byte.ascii.space   // Latin1.Byte(0x20)
//   ...
```

No per-type plumbing for ASCII constants. The `Carrier.Protocol where Underlying == UInt8`
extension picks up Latin1.Byte by conformance; `ASCII.Of<Latin1.Byte>`
is well-formed; the delegation `Owner(ASCII.Code.X.underlying)` produces
`Latin1.Byte(0x61)` for the 'a' case.

### Sketch — `UTF8.Code_Unit` adoption

Same shape. `UTF8.Code_Unit` (hypothetical future from a UTF-8 primitives
package) conforms `Carrier.Protocol<UInt8>` (UTF-8 code units are bytes
in the 0x00–0xFF range); automatically gains `.ascii.X` for the 0x00–0x7F
subset that overlaps with ASCII. The fact that UTF-8 code units outside
0x00–0x7F have non-ASCII semantics doesn't affect this surface — ASCII
constants are defined as the 128 7-bit values, and a UTF8.Code_Unit
constructed from one of those values IS a valid UTF-8 byte representing
the corresponding ASCII character (by UTF-8's design invariant).

### Sketch — RFC-specific byte types

For hypothetical types like `RFC_3986.URI.Octet` (a typed wrapper for
URI-component bytes), the same Carrier.Protocol<UInt8> conformance
gives `.ascii.X` access. If the RFC defines a *restricted* alphabet
(e.g., URI scheme byte values), additional constants specific to that
RFC live on the RFC-specific type or in an RFC-specific wrapper
(`RFC_3986.URI.Of<Owner>` analog if needed); the ASCII layer remains
the universal substrate.

### Tagged-Recursive Conformance

The recursive `Tagged<Tag, T>: Carrier.Protocol where Underlying: Carrier.Protocol`
conformance (from swift-tagged-primitives) carries the carrier-axis
through Tagged wrappers. Consequently:

```swift
let id: Tagged<UserID, Byte> = ...
// Tagged<UserID, Byte>: Carrier.Protocol where Underlying == Byte.Underlying == UInt8
// Therefore Tagged<UserID, Byte>.ascii is well-formed:
let sep = Tagged<UserID, Byte>.ascii.space   // Tagged<UserID, Byte>(0x20)
```

This is rarely useful at consumer sites (you typically don't compare a
typed-ID to an ASCII codepoint), but it composes correctly — no
structural exception for Tagged wrappers.

## Rejected Alternatives Summary

| Option | Failure tier | Reason |
|--------|--------------|--------|
| A — `Namespace<Owner>` (the interim) | Tier 3 (cleanliness — naming) | Principal: *"the Namespace wrapper has no semantic weight."* Generic-structural names rejected by `protocol-abstraction-for-phantom-typed-wrappers.md` precedent. The *mechanism* is sound; only the *name* is wrong. |
| B — Static subscript (`byte[ascii: .space]`) | Tier 2 (ergonomics) | Breaks `*.ascii.X` infix per K2; bracket-shape at consumer sites. |
| D — Macros | Tier 3 (cleanliness) + Tier 4 (extensibility) | Per-type expansion = N × 128 declarations; macro hides per-domain choices; recipe is too simple to justify the indirection. Per byte-protocol-capability-marker.md Q2 closure. |
| E — KeyPath-driven | Tier 2 (ergonomics) + Tier 3 (cleanliness) | Breaks infix per K2; KeyPaths don't fit cross-carrier Self-resolution cleanly. |
| E' — `@dynamicMemberLookup` + KeyPath | DEFERRED (Swift-mechanic uncertainty) | Static-property KeyPath via dynamic member lookup has evolving Swift support; the 128-line wrapper cost in Option C is acceptable; gain is non-load-bearing. Revisit as optimization arc if needed. |
| F — Phantom-typed enum cases | Tier 2 (ergonomics) | Function-call shape `.ascii(.a)` breaks infix per K2; enum-cases-as-constants is unusual idiom. |
| G1 — Per-conformer extension | Tier 4 (extensibility) + Tier 3 (per-type duplication) | Future newtypes copy 128 constants per type; unbounded growth. |
| G2 — Top-level + per-carrier wrap | K2 violation | Explicit `Type(.X)` wrap loses the `.ascii.` infix prefix. |
| G3 — ASCII.Code-as-Tagged-typealias | Out-of-scope | Settled by `ascii-code-structural-shape.md` v1.0.0 Shape (a); not re-litigated here. |
| G4 — Concrete struct wrapper | Type-system cleanliness | Stored Owner-typed constants consume runtime memory per instantiation; `@frozen public enum` with `@inlinable` computed statics is the zero-cost form. |

## Cognitive Dimensions Empirical Validation ([RES-025])

| Dimension | Disposition under recommendation |
|-----------|----------------------------------|
| **Visibility** | Consumers see `ASCII.Code.X` (autocomplete on the canonical type) AND `<Carrier>.ascii.X` (autocomplete on the wrapper via IDE). Two discoverable paths to the same value. |
| **Consistency** | Single mechanism (Option C `ASCII.Of<Owner>`) covers all UInt8-carrier conformers. No per-type special cases. |
| **Viscosity** | Adding a new ASCII constant requires 2 source edits: ASCII.Code (canonical) + ASCII.Of (delegation). Bounded; the ASCII codepoint set is fixed by INCITS 4-1986 — additions are vanishingly rare. |
| **Role-expressiveness** | Wrapper name `ASCII.Of<Owner>` reads as "ASCII of Owner" — function-style projection. Reader infers cross-carrier projection from the name. |
| **Error-proneness** | Migration: replacing UInt8-back-compat `ASCII.Code.X` with ASCII.Code-typed could silently change overload resolution in some sites. Mitigation: type-checked migration (compile errors surface most cases); manual review of sites in swift-terminal-primitives (which uses `case ASCII.Code.X` patterns extensively). |
| **Abstraction** | One level of abstraction (the wrapper as cross-carrier projection); not over-abstracted. The wrapper has no behavioral methods, only 128 statics; structural simplicity is preserved. |
| **Hard mental operations** | None new. Consumers already mentally model `.ascii.X` as "ASCII codepoint X, typed appropriately" (the 992 existing sites prove the model is durable). |

## Open Follow-Ups

Items the recommendation explicitly defers:

1. **`ASCII.whitespaces`** (currently `Set<UInt8>` in `ASCII.swift`) —
   migrate to `Set<ASCII.Code>`? Pros: type-domain consistency with the
   absorbed ASCII.Code-typed shape. Cons: `Set<UInt8>` is broadly
   compatible with `Collection<UInt8>` consumers; `Set<ASCII.Code>`
   requires explicit element wrapping at consumer sites. Decision:
   defer; consumers may keep `Set<UInt8>` as a stdlib-bridge collection,
   or migrate to `Set<ASCII.Code>` with the recommendation. Surface to
   principal at execution time.

2. **`ASCII.Character.Control.crlf: [UInt8]`** — migrate to
   `[ASCII.Code]`? The CRLF array is a specific byte sequence (0x0D
   0x0A); whether its type stays `[UInt8]` or migrates to `[ASCII.Code]`
   is a small consumer-coordination question. Defer to execution-time
   decision per the same logic as Open Follow-Up 1.

3. **ASCII.Of-naming runner-up `ASCII.Constants<Owner>`** — if the
   maintainer prefers a more descriptive name over the function-style
   "Of", the rename is mechanical (single-source change). Both names
   satisfy Tier 3; the choice is a judgment call that this
   recommendation leaves open with `ASCII.Of<Owner>` as primary.

4. **Dynamic member lookup variant (Option E')** — revisit if Swift's
   static-property KeyPath support stabilizes. The gain (eliminating
   128-line wrapper duplication) is non-load-bearing; the
   recommendation's Option C is robust without it.

5. **ASCII-arithmetic ergonomics** (per `bsli-gap-inventory.md`'s open
   friction note) — `value = value * 10 + Int(byte.underlying - 0x30)`
   ASCII digit-decoding friction is a separate question. Re-examining
   no-arithmetic-on-Byte vs introducing an ASCII-digit numeric type is
   independent of the constants layer. Surface to principal as a
   distinct future arc.

6. **`swift-ascii-primitives/Research/_index.json`** is missing
   ([RES-003c] non-compliance: the directory contains 2+ documents
   without an index file). The directory also contains a `_work/`
   subdirectory which is forbidden per [RES-002] (no underscore-prefixed
   subdirectories in `Research/`). Both are **pre-existing** non-
   compliance, not introduced by this arc. Cleanup arc recommended;
   not blocking on this arc.

7. **`Tagged<Tag, ASCII.Code>` recursive composition for phantom-tagged
   ASCII domains** — currently works automatically via the recursive
   Tagged conformances to Carrier.Protocol and Byte.Protocol. No
   explicit consumer sites in the surveyed corpus, but the mechanism is
   sound for future RFC-specific or domain-specific ASCII subset types.
   No action required; documented for future reference.

## What This Closes / What Remains Open

### Closed

- **Q1 — Mechanism**: closed by Verdict 1. Owner-parameterized empty
  enum (Option C) with `ASCII.Of<Owner>` naming. Mechanism is the same
  as the interim Namespace<Owner>; only the name changes to carry
  domain meaning.
- **Q2 — Canonical literal home**: closed by Verdict 2. ASCII.Code's
  Self-typed `@inlinable` static computed properties. Single source of
  truth.
- **Q3 — ASCII.Character.\* disposition**: closed by Verdict 3.
  Absorbed into ASCII.Code with spec-categorization preserved via MARK
  groups + classification predicates.
- **Q4 — Consumer migration**: closed by Verdict 4. Per-site rewrite
  table; bounded scope; type-checked migration.
- **Mechanism options A, B, D, E, E', F, G1, G2, G3, G4**: closed,
  rejected with tier-citation in the table above.

### Open (Follow-on)

See Open Follow-Ups section above.

## What This Does NOT Recommend

- **No change to ASCII.Code's structural shape** — Shape (a) from
  `ascii-code-structural-shape.md` v1.0.0 is preserved (standalone
  struct wrapping UInt8 + Byte.Protocol sibling-form conformance).
- **No new generic type at the consumer surface** — `ASCII.Of<Owner>`
  is a maintainer-side mechanism; consumers see only `Type.ascii.X`
  infix, never the wrapper type directly.
- **No deprecation paths for existing UInt8-typed `ASCII.Code.X`
  constants** — per K4, no back-compat optimization. The constants
  disappear under the recommendation; consumers migrate per Verdict 4.
- **No retreat from `Carrier.Protocol<UInt8>` as the scoping protocol** —
  the parent arc's decision to extend `Carrier.Protocol where Underlying == UInt8`
  (not `Byte.Protocol`) is preserved. UInt8 participates as a UInt8-carrier
  via trivial-self-carrier; the byte-vs-arithmetic identity separation
  is maintained because constants are value lookups (not behavioral
  additions).
- **No language-feature dependency beyond what's currently shipping** —
  the recommendation uses only Swift 6 features in production:
  `@frozen` enum, generic constraints, `@inlinable` computed properties,
  protocol extensions. No `@dynamicMemberLookup` (deferred per Option E'),
  no macros, no parameter-pack innovations.

## Formal Semantics ([RES-024])

### Type Definitions

```
Types:
  Carrier.Protocol             -- protocol with associatedtype Underlying
                                  and witnesses { underlying: Underlying { get };
                                                  init(_: consuming Underlying) }
  ASCII.Code                   -- @frozen struct { underlying: UInt8 }
  ASCII.Of<Owner>              -- @frozen empty enum, generic over Owner
  Tagged<Tag, T>               -- phantom-typed wrapper (from swift-tagged-primitives)

Constraints on Carrier.Protocol-using sites:
  ASCII.Of<Owner> where Owner: Carrier.Protocol, Owner.Underlying == UInt8

Conformances inherited by the recommendation:
  UInt8 : Carrier.Protocol            (Underlying = UInt8, trivial self-carrier)
  Byte : Carrier.Protocol              (Underlying = UInt8)
  Byte : Byte.Protocol                 (sibling to Carrier; per byte-protocol-capability-marker.md)
  ASCII.Code : Carrier.Protocol        (Underlying = UInt8)
  ASCII.Code : Byte.Protocol           (sibling)
  Tagged<Tag, T> : Carrier.Protocol    (where T: Carrier.Protocol, Tag: ~Copyable;
                                        Underlying = T.Underlying via recursive carrier)
```

### Typing Rules

**Canonical static access** (single source of truth on `ASCII.Code`):

```
  ASCII.Code : @frozen struct
  ─────────────────────────────
  Γ ⊢ ASCII.Code.a : ASCII.Code
```

**Cross-carrier projection** (via `ASCII.Of<Owner>`):

```
  Γ ⊢ Owner : Carrier.Protocol     Owner.Underlying == UInt8
  ─────────────────────────────────────────────────────────────
  Γ ⊢ ASCII.Of<Owner>.a : Owner

  with body: Owner(ASCII.Code.a.underlying)
       i.e.: Owner(0x61 as UInt8)
```

**Consumer-site infix access** (via `Carrier.Protocol<UInt8>` extension):

```
  Γ ⊢ T : Carrier.Protocol     T.Underlying == UInt8
  ──────────────────────────────────────────────────────
  Γ ⊢ T.ascii.a : T

  which desugars to: ASCII.Of<T>.a : T
                  = T(ASCII.Code.a.underlying)
                  = T(0x61 as UInt8)
```

**Self-resolving consumer-site comparison** (the canonical ergonomic
pattern):

```
  Γ ⊢ x : T     T : Carrier.Protocol     T.Underlying == UInt8
  T : Equatable
  ─────────────────────────────────────────────────────────────
  Γ ⊢ x == .ascii.a : Bool

  with .ascii.a inferred as T.ascii.a : T
       (via Self-resolution at the type-checker's contextual-type
        inference for the `==` operator's right-hand side)
```

### Soundness Argument

The recommendation is sound (does not introduce type confusion) because:

1. **Single source of truth**: ASCII.Code's static constants are the
   only place where the 128 literal byte values are written as
   literals. `ASCII.Of<Owner>.X` constructs `Owner` from
   `ASCII.Code.X.underlying`. Any change to the literal value is
   automatically reflected in all carriers via the delegation. No
   drift possible.

2. **Type preservation**: For each carrier `T: Carrier.Protocol`
   where `T.Underlying == UInt8`, the static `ASCII.Of<T>.X` returns a
   `T`-typed value. Round-trip property:
   `ASCII.Of<T>.X.underlying == ASCII.Code.X.underlying` (the byte
   value is preserved across the projection).

3. **No phantom-tag leakage**: For `Tagged<Tag, T>` participating via
   recursive Tagged conformance, the tag is irrelevant to the projection
   — `ASCII.Of<Tagged<Tag, T>>.X` constructs `Tagged<Tag, T>` via
   `Tagged<Tag, T>(ASCII.Code.X.underlying)` which uses Tagged's
   `init(_: consuming Underlying)` per the Carrier.Protocol witness.
   The phantom tag is set to its default — typically requiring a
   `__unchecked:` constructor or equivalent in Tagged's universal
   conformance, which is provided by swift-tagged-primitives.

4. **No byte-vs-arithmetic identity dissolution**: per the
   byte-protocol-capability-marker.md discipline, UInt8 participates via
   `Carrier.Protocol<UInt8>` (its carrier identity), NOT via
   `Byte.Protocol` (which it does not conform to). The ASCII constants
   are value lookups, not behavioral additions; UInt8's
   arithmetic-algebras identity is preserved (still has `+ - * /`); its
   carrier identity gives it access to ASCII codepoints as UInt8 values.
   Byte / ASCII.Code / future newtypes participate via their own
   Carrier.Protocol<UInt8> conformance (orthogonal to their Byte.Protocol
   conformance).

5. **Parametricity**: `ASCII.Of<Owner>` is a phantom-typed namespace
   (the Owner type appears in the result type but not in the namespace's
   stored state — there is no stored state). Operations through the
   namespace cannot inspect Owner's representation; they only construct
   Owner values via `Owner(_: consuming UInt8)`. This is the standard
   phantom-type parametricity guarantee — Owner's representation does
   not leak into ASCII.Of's behavior.

## References

### Internal — Authoritative

- [`swift-institute/Research/byte-protocol-capability-marker.md`](../../../swift-institute/Research/byte-protocol-capability-marker.md) v1.1.0 (Tier 3 RECOMMENDATION, 2026-05-15) — load-bearing for Tier 1 (semantic identity separation, byte-vs-arithmetic discipline) and Tier 4 (per-domain X.Protocol recipe).
- [`swift-institute/Research/byte-primitive-extraction-and-domain-naming.md`](../../../swift-institute/Research/byte-primitive-extraction-and-domain-naming.md) v1.0.1 (Tier 2 DECISION, 2026-05-15) — the predecessor arc; identified ASCII.Code as the canonical byte-domain conformer.
- [`swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md`](../../../swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md) v1.4.0 (Tier 3 DECISION/IMPLEMENTED, 2026-02-13) — canonical per-type X.Protocol pattern + rejection of unified-protocol (generic-structural) alternatives. Naming-precedent for rejecting `Namespace<Owner>`.
- [`swift-institute/Research/ascii-code-structural-shape.md`](../../../swift-institute/Research/ascii-code-structural-shape.md) v1.0.0 (Tier 2 RECOMMENDATION, 2026-05-16) — the immediate predecessor; structural shape of ASCII.Code as standalone struct + Byte.Protocol sibling-form conformance. Sets the foundation this arc builds on.
- [`swift-institute/Research/ascii-parsing-domain-ownership.md`](../../../swift-institute/Research/ascii-parsing-domain-ownership.md) v4.2.0 (Tier 2 RECOMMENDATION, 2026-03-04) — the subject-first ASCII namespace ordering. Confirms ASCII as the canonical domain owner.
- [`swift-institute/Research/cardinal-protocol-unification-memo.md`](../../../swift-institute/Research/cardinal-protocol-unification-memo.md) (SUPERSEDED 2026-05-04) — live-fire precedent for the Cardinal.Protocol sibling recipe; six-package empirical evidence for cross-carrier code-deduplication via per-domain X.Protocol.
- [`swift-byte-primitives/Research/bsli-gap-inventory.md`](../../swift-byte-primitives/Research/bsli-gap-inventory.md) — friction inventory from the byte-adoption arc; records the interim ASCII.Namespace<Owner> + flags ASCII-arithmetic-ergonomics open follow-up.
- `HANDOFF-byte-adoption-substrate-and-sli.md` (parent arc Findings) — records the interim shape and the supersession authorization for this arc.

### Internal — Source Files Referenced

- [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code.swift`](../Sources/ASCII%20Primitives/ASCII.Code.swift) — typed-ASCII-byte struct (Shape (a) per ascii-code-structural-shape.md).
- [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Constants.swift`](../Sources/ASCII%20Primitives/ASCII.Code+Constants.swift) — current UInt8-back-compat constants; subject to flip under Verdict 2.
- [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Character.Graphic.swift`](../Sources/ASCII%20Primitives/ASCII.Character.Graphic.swift) — current spec-categorized UInt8 literal source; absorbed under Verdict 3.
- [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Character.Control.swift`](../Sources/ASCII%20Primitives/ASCII.Character.Control.swift) — current spec-categorized UInt8 literal source; absorbed under Verdict 3.
- [`swift-ascii-primitives/Sources/ASCII Primitives/Carrier.Protocol+ASCII.swift`](../Sources/ASCII%20Primitives/Carrier.Protocol+ASCII.swift) — interim `ASCII.Namespace<Owner>` implementation; superseded by Verdict 1.
- [`swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Byte.Protocol.swift`](../Sources/ASCII%20Primitives/ASCII.Code+Byte.Protocol.swift) — sibling-form conformance per byte-protocol-capability-marker.md.
- [`swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift`](../../swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol.swift) — Byte.Protocol declaration + recursive Tagged conformance.

### External — Verified Primary Sources

- **Swift Standard Library `Integers.swift`**: https://raw.githubusercontent.com/swiftlang/swift/main/stdlib/public/core/Integers.swift — FixedWidthInteger / BinaryInteger hierarchy; UInt8's arithmetic-algebras identity (verified 2026-05-19; transitively via byte-protocol-capability-marker.md).
- **pointfreeco/swift-tagged**: https://github.com/pointfreeco/swift-tagged — Tagged-per-tag constants pattern; cited in byte-protocol-capability-marker.md.
- **Rust Book ch10-02 + ch20-02**: https://doc.rust-lang.org/book/ — newtype pattern + orphan rule (transitively via byte-protocol-capability-marker.md §2.1).
- **Haskell Wiki, Newtype**: https://wiki.haskell.org/Newtype — newtype convention for declaring different typeclass instances on structurally-identical values (transitively via byte-protocol-capability-marker.md §2.2).
- **INCITS 4-1986 (R2022)**: 7-Bit American Standard Code for Information Interchange — sections 4.1 (Control Characters), 4.3 (Graphic Characters), 4.4 (SPACE) — referenced by `ASCII.swift`, `ASCII.Character.Graphic.swift`, `ASCII.Character.Control.swift`.

### Skill Rules

- `[RES-001]` Investigation Triggers — research-process.
- `[RES-002]` Document Location Convention — research-process. (Per-package home; per-package Research/.)
- `[RES-003]` Document Structure — research-process. (Title / Metadata / Context / Question / Analysis / Outcome.)
- `[RES-003c]` Research Index — research-process. (Per-package `_index.json`; flagged as open follow-up — missing today.)
- `[RES-019]` Internal Research Grep — research-process. (Internal-first governance; external survey is contextualization.)
- `[RES-020]` Research Tiers — research-process. (Tier 3 threshold satisfied: precedent-setting, ecosystem-wide, timeless lifetime.)
- `[RES-021]` Prior Art Survey + contextualization step — research-process. (Cross-system patterns concretized in the ecosystem's terms before classifying as gap.)
- `[RES-022]` Recommendation-Section Framing Heuristic — research-process. (Structural correctness over diff-size; document exceptions explicitly.)
- `[RES-023]` Systematic Literature Review — research-process. (Inherits foundational SLR from `phantom-typed-value-wrappers-literature-study.md`.)
- `[RES-024]` Formal Semantics — research-process. (Typing rules + soundness argument above.)
- `[RES-025]` Empirical Validation (Cognitive Dimensions) — research-process. (CDF table above.)
- `[RES-026]` Citations — research-process. (Plain Markdown links; no BibTeX.)
- `[RES-029]` Framing-Challenge for Binding/Membership/Placement Questions — research-process. (Tier 1 semantic identity ranked first.)
- `[API-NAME-001]` Nest.Name Pattern — code-surface. (ASCII.Of follows the pattern.)
- `[API-NAME-001c]` Per-Domain Capability-Marker Protocol — code-surface. (The recipe Byte.Protocol instantiates; ASCII.Code inherits.)
- `[API-NAME-003]` Specification-Mirroring Names — code-surface. (ASCII codepoints mirror INCITS 4-1986 terminology; section grouping preserved via MARK comments.)
- `[IMPL-102]` Super-Protocol Verifiability Under Swift Overlapping-Conformance Rules — implementation. (Blocks meta-protocol Option D variants.)

## Changelog

- **v1.0.0** (2026-05-19) — Initial recommendation. Discharges the
  question deferred by `HANDOFF-ascii-typed-constants-design.md` (the
  arc's investigation brief). Four jointly-coherent verdicts:
  - Q1 mechanism: Option C with `ASCII.Of<Owner>` naming.
  - Q2 canonical literal home: `ASCII.Code` Self-typed statics.
  - Q3 ASCII.Character.* disposition: ABSORB into ASCII.Code with
    spec-categorization preserved via MARK groups.
  - Q4 consumer migration: per-site rewrite table; ~270 source rewrites
    across ~9 packages; bounded risk; type-checked migration.
