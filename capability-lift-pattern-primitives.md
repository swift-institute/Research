# Capability-Lift Pattern

<!--
---
version: 1.2.0
last_updated: 2026-04-23
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

<!--
Changelog:
- v1.2.0 (2026-04-23): Added §"Why a separate Carrier package was considered
  and rejected" documenting the structural composition limit (recursive Tagged
  conformances don't compose with refinement protocols like Ordinal.Protocol)
  and the absence of demonstrated use cases. Softened Recommendations to
  reflect this — super-protocol introduction is DEFERRED, not endorsed.
  Cross-references to swift-property-primitives/Research/property-tagged-semantic-roles.md
  v1.1.0+ (Group A admits super-protocol in principle; Group B does not).
- v1.1.0 (2026-04-22): Added §"Tagged as the canonical Carrier" — clarifies
  that Carrier IS the abstract interface that Tagged is the free/canonical
  generic implementation of. Sharpened Recommendation #2. Added §"Worked
  example" with a pedagogical walkthrough. Added §"How to read this in
  practice" guide.
- v1.0.0 (2026-04-22): Initial recommendation; six experiment variants;
  Option A (refinement) vs Option B (parameterized) analysis.
-->

## Context

`swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift`
and `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift`
both implement a *capability-lift pattern*: a concrete value type V (`Cardinal`,
`Ordinal`) is paired with a hoisted-style protocol `V.\`Protocol\`` that abstracts
the value's role. Bare V conforms with `Domain = Never`; `Tagged<Tag, V>` conforms
conditionally with `Domain = Tag`. APIs declared in terms of `some V.\`Protocol\``
accept both forms transparently.

The user's design framing: **value types are primary; protocols are additive.**
Cardinal/Ordinal are concrete in normal use; their `.\`Protocol\`` forms exist
so APIs can opt into broader acceptance.

This document characterizes the pattern's recipe and explores how far it
generalizes. Companion: `capability-lift-pattern-academic-foundations.md`
provides theoretical grounding (parametricity, free constructions, fibrations).

**Trigger**: [RES-012] Discovery — proactive characterization.

**Scope**: Cross-package. **Tier**: 2.

## Worked example: what is the pattern, and how is it used?

### The problem

```swift
typealias ByteCount      = Tagged<Bytes,  Cardinal>
typealias FrameCount     = Tagged<Frames, Cardinal>
typealias Index<E>.Count = Tagged<E,      Cardinal>
```

Want `align(_:)` to work on bare Cardinal AND every Tagged-wrapped variant
without giving up phantom typing at call sites.

### The recipe (per-type)

```swift
extension Cardinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}

extension Cardinal: Cardinal.`Protocol` {
    public typealias Domain = Never
    public var cardinal: Cardinal { self }
    public init(_ cardinal: Cardinal) { self = cardinal }
}

extension Tagged: Cardinal.`Protocol`
where RawValue == Cardinal, Tag: ~Copyable {
    public typealias Domain = Tag
    public var cardinal: Cardinal { rawValue }
    public init(_ cardinal: Cardinal) { self.init(__unchecked: (), cardinal) }
}

extension Cardinal.`Protocol` {
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(Cardinal(lhs.cardinal.raw + rhs.cardinal.raw))
    }
}
```

API site:
```swift
func align<C: Cardinal.`Protocol`>(_ c: C) -> C {
    C(Cardinal((c.cardinal.raw + 7) & ~7))
}

let a: Cardinal   = align(Cardinal(13))
let b: ByteCount  = align(ByteCount(.init(13)))
let c: FrameCount = align(FrameCount(.init(13)))
```

The `init(_ cardinal:)` is the phantom-preserving reconstructor — when `align`
returns `C(Cardinal(aligned))`, the conformer's init wraps the value back up
with its original Tag.

## Tagged as the canonical Carrier

A natural design question: is `Carrier<Underlying>` (a hypothetical
super-protocol unifying all Cardinal-shaped, Ordinal-shaped, etc.
per-type protocols) equivalent to a hypothetical `Tagged<A, B>.\`Protocol\``?

**Strict answer**: no. Tagged.\`Protocol\` describes "things shaped like
Tagged." Bare Cardinal doesn't conform — no `__unchecked:` init, no phantom
Tag. Carrier accepts bare Cardinal via `Domain = Never` (the trivial
self-carrier).

**Spiritual answer**: yes. Strip away the bare case and the two collapse.
Tagged is the canonical generic implementation of Carrier — given any
`(Tag, V)`, `Tagged<Tag, V>` produces a Carrier with `Domain = Tag`,
`Underlying = V` via parametric extension. Bare types conform separately
as trivial Carriers.

The relationship is:

| Abstract interface | Canonical generic implementation |
|--------------------|----------------------------------|
| `Sequence` | `Array<T>` (any T → free Sequence of T) |
| Optional-like | `Optional<T>` (any T → free nullable T) |
| `Carrier` | `Tagged<Tag, V>` (any (Tag, V) → free Carrier with Domain=Tag, Underlying=V) |

## Why a separate Carrier package was considered and rejected

Earlier drafts (v1.0–v1.1) explored introducing `Carrier` as a top-level
super-protocol unifying Cardinal.\`Protocol\`, Ordinal.\`Protocol\`,
Hash.\`Protocol\`, etc. The exploration concluded **no** for three reasons.

### Problem 1 — Single-protocol package violates per-canonical-type convention

Every existing tier-0 protocol-bearing package contains a concrete type
alongside the protocol (Array struct + Array.\`Protocol\`; Set struct + Set.\`Protocol\`;
Cardinal struct + Cardinal.\`Protocol\`). A `swift-carrier-primitives`
package would contain only the abstract protocol, no concrete type — the
[API-NAME-001a] single-type-namespace antipattern at the package level.

The protocol could live at top level (no namespace), but the package
itself still has one item. No ecosystem precedent for "package containing
just an abstract protocol" without a concrete partner.

### Problem 2 — Tagged: Carrier doesn't compose with refinement protocols

This is the structural blocker. Two options for Tagged's Carrier conformance:

**Universal**: `extension Tagged: Carrier where RawValue: Copyable, Tag: ~Copyable { Underlying = RawValue }`.
Then `Tagged<A, Tagged<B, Cardinal>>.Underlying == Tagged<B, Cardinal>`,
NOT Cardinal. So `some Carrier<Cardinal>` rejects two-deep tagged values.
Unification is incomplete.

**Per-Underlying**: each package authors its own Tagged: Carrier. But
for Ordinal.\`Protocol\`-style refinements (where Tagged conformance uses
`RawValue: __Ordinal_Protocol` for nested support), Underlying needs to
be `Ordinal` — not `RawValue`. This conflicts with the universal
"Underlying == RawValue" reading. The recursive-via-Carrier extension
`extension Tagged: Carrier where RawValue: Carrier, RawValue.Underlying == Cardinal`
overlaps with the direct `RawValue == Cardinal` extension and Swift forbids
overlapping conditional conformances.

Production today resolves this by NOT having a super-protocol — each
type's `*.Protocol` handles its own recursion via the named accessor
(`var ordinal: Ordinal { rawValue.ordinal }` on the recursive Tagged
conformance). **Carrier as super-protocol breaks this**: it requires
Tagged.Underlying to mean one thing universally, but Ordinal.\`Protocol\`
needs Underlying = Ordinal regardless of nesting depth.

The academic Carrier framing is theoretically clean. Swift's expressiveness
limits make it incomplete.

### Problem 3 — No demonstrated use case

The main payoff from a super-protocol is fully-generic algorithms
(`func describe<C: Carrier>(_ c: C)` — diagnostics, cross-Carrier
conversions, serialization scaffolding). None exist in production today.
The need is speculative.

The per-type pattern (Cardinal.\`Protocol\`, Ordinal.\`Protocol\`) handles
all CURRENT use cases. Carrier solves a problem that hasn't surfaced.

### Decision: defer

Don't introduce `swift-carrier-primitives` and don't introduce a Carrier
super-protocol generally. The per-type-protocol design is the version
that actually composes in Swift. If a concrete cross-Carrier use case
ever surfaces, revisit then with API in hand. Adding Carrier later is
purely additive — no breaking change.

**Cross-reference**: `swift-property-primitives/Research/property-tagged-semantic-roles.md`
v1.1.0+ §"Categorical asymmetry" makes the complementary point:
Group A admits a super-protocol *in principle* (the abstraction is
coherent), but the asymmetry with Group B (verb-namespace, doesn't admit
unification because tags are local) was already part of the design space.
This document's Problem 2 sharpens that to: **Group A admits unification
in theory; Swift's expressiveness blocks it in practice.**

## Recommendations

The following recommendations supersede earlier drafts (v1.0–v1.1) which
endorsed introducing Carrier. The empirical investigation in v1.2.0 walked
this back.

| # | Recommendation | Status |
|---|---|---|
| R1 | Keep per-type protocols (Cardinal.\`Protocol\`, Ordinal.\`Protocol\`, Hash.\`Protocol\`) | **Keep current** |
| R2 | Do NOT introduce a `Carrier<Underlying>` super-protocol or `swift-carrier-primitives` package today | **Deferred** (per Problem 1+2+3) |
| R3 | Preserve the parameter-order convention (Tag first, Value second) across all Group A primitives | **Keep current** |
| R4 | Document the Tagged-is-canonical-implementation framing (this doc + academic-foundations) | **Done in v1.1.0** |
| R5 | If a concrete cross-Carrier use case emerges (e.g., a phantom-aware diagnostic helper that genuinely needs `any Carrier<X>`), revisit Carrier with API in hand | **Conditional / future** |
| R6 | Don't relax `Domain: ~Copyable` — load-bearing for parametricity per academic-foundations §5.4 | **Keep current** |

## How to read this in practice

| If you're... | Use |
|---|---|
| Writing an API for `Cardinal` quantities | `func f<C: Cardinal.\`Protocol\`>(_ c: C) -> C` |
| Writing an API for `Ordinal` positions | `func f<O: Ordinal.\`Protocol\`>(_ o: O) -> O` |
| Adding a new Tag to existing value type V | `typealias MyCount = Tagged<MyTag, V>` — conformance to V.\`Protocol\` is parametric, free |
| Adding a new value type V to the family | Two extensions: `extension V: V.\`Protocol\`` and `extension Tagged: V.\`Protocol\` where RawValue == V` |
| Wanting cross-V genericity | Don't have it today; add a `Carrier`-style super-protocol IF the use case is real (revisit) |

## References

### Primary sources

- `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` — Cardinal.\`Protocol\` exemplar.
- `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift` — Ordinal.\`Protocol\` with Count refinement.
- `swift-hash-primitives/Sources/Hash Primitives Core/Hash.Protocol.swift` — Hash.\`Protocol\` (witness role, distinct from Carrier).

### Companion research

- `swift-primitives/Research/capability-lift-pattern-academic-foundations.md` — academic survey grounding the recipe; provides fibration vocabulary.
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` (v1.1.0+) — Group A / Group B taxonomy; categorical asymmetry argument supports R2 above.

### Convention sources

- [PKG-NAME-001/002], [API-NAME-001/001a], [API-IMPL-009].
