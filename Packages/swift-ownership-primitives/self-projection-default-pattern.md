# Self-Projection Default Pattern

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: cross-package
supersedes_lost: swift-primitives/Research/self-projection-default-pattern.md (authored 2026-04-22, lost mid-session 2026-04-23)
---
-->

## Context

`Ownership.Borrow.\`Protocol\`` in `swift-ownership-primitives/Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift` exhibits a specific protocol shape:

```swift
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = Ownership.Borrow<Self>
}
```

The `Borrowed` associated type **defaults to a generic type over `Self`** — `Ownership.Borrow<Self>`. Conformers who want the default borrow representation get it for free:

```swift
extension SomeValue: Ownership.Borrow.`Protocol` {}     // Borrowed = Ownership.Borrow<SomeValue> (default)
extension Path: Ownership.Borrow.`Protocol` {           // Borrowed = Path.Borrowed (explicit override)
    public typealias Borrowed = Path.Borrowed
}
```

Plus the canonical spelling `Ownership.Borrow.\`Protocol\`` is exposed via a typealias nested inside the generic struct:

```swift
public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
    public typealias `Protocol` = __Ownership_Borrow_Protocol
}
```

This is a **self-projection default pattern**: a protocol whose associated type defaults to a generic container `N<Self>` where `N` is a concrete type that already exists in the ecosystem. The conformer either accepts the default (its borrowed form IS `N<Self>`) or overrides with a custom nested type.

The pattern is deliberate and load-bearing. It lets types opt into the protocol with a single empty `extension T: Ownership.Borrow.\`Protocol\` {}` when the default `N<Self>` is right for them, while leaving the door open for conformers with interior storage (Path's UTF-8 buffer, String's grapheme clusters) to ship a custom `Borrowed` type that's more efficient or semantically richer than a raw wrapper.

This document characterizes the pattern as a reusable meta-shape, enumerates candidate instances across the primitives ecosystem, and separates the structural and semantic preconditions that determine whether a given protocol can adopt it.

**Trigger**: [RES-012] Discovery — proactive characterization of a recurring shape. The pattern landed first as `Ownership.Borrow.\`Protocol\`` (IMPLEMENTED 2026-04-23, see `swift-institute/Research/ownership-borrow-protocol-unification.md`). Generalization to other candidate protocols was the subject of an experiment and research doc authored on 2026-04-22 and lost mid-session 2026-04-23; this document re-authors the characterization from the surviving concrete instance + the reflection record.

**Scope**: cross-package. The pattern's canonical instance lives in `swift-ownership-primitives`, but candidate instances span `swift-ownership-primitives` (Borrow canonical, Mutate hypothetical), `swift-property-primitives`, `swift-hash-primitives`, and `swift-memory-primitives`. Placed here because the canonical and likely-next instance (Mutate / Inout) are both in this package.

**Tier**: 2 (Standard) — characterizes a pattern across packages without establishing a normative semantic contract. The contract itself (Ownership.Borrow.`Protocol`'s shape) is already IMPLEMENTED and frozen per the unification DECISION; this document explains what makes it work and when to reach for it again.

## Question

Four sub-questions:

1. **What's the pattern's precise shape?** State the recipe so a protocol author can decide whether their protocol fits.
2. **When does the pattern fit?** What structural and semantic preconditions must the conforming type hold?
3. **When does it not fit?** What shapes break the pattern — and are those breakages structural (Swift can't express it) or semantic (Swift accepts it but the meaning is wrong)?
4. **How does this pattern relate to the capability-lift pattern** (in `swift-carrier-primitives/Research/capability-lift-pattern.md`)? Are they orthogonal, overlapping, or in tension?

## Analysis

### The recipe

The pattern consists of three declarations plus a conformance pattern:

```swift
// 1. The generic container N<Value>. Concrete type with ~Copyable (and
//    typically ~Escapable) Value parameter. The projection's semantics
//    live here.
extension Namespace {
    public struct N<Value: ~Copyable & ~Escapable>: /* constraints */ {
        // Storage that projects Value. E.g., raw pointer for a borrow,
        // mutable pointer for an inout, box for a move.
    }
}

// 2. The hoisted protocol (module-scope because SE-0404 does not permit
//    protocol nesting inside a generic struct). The default associated
//    type defaults to N<Self>.
public protocol __Namespace_N_Protocol: ~Copyable, ~Escapable {
    associatedtype Projected: ~Copyable, ~Escapable = Namespace.N<Self>
}

// 3. The canonical spelling via a nested typealias. Conformers write
//    Namespace.N.`Protocol`, not the double-underscored module-scope name.
extension Namespace.N where Value: ~Copyable & ~Escapable {
    public typealias `Protocol` = __Namespace_N_Protocol
}

// 4. The conformance pattern — two forms.
//    (a) Default — empty extension. Projected resolves to Namespace.N<Self>.
extension ConcreteType: Namespace.N.`Protocol` {}

//    (b) Override — explicit nested type. Projected resolves to the custom.
extension ConcreteType: Namespace.N.`Protocol` {
    public typealias Projected = ConcreteType.Projected  // a nested struct
}
```

Three features collaborate:

- The **associated-type default** (`= Namespace.N<Self>`) eliminates per-conformer boilerplate for the common case.
- The **hoisted protocol + nested typealias** is forced by SE-0404 (no protocol nesting in generic types). It's a spelling workaround, not a semantic choice.
- The **suppression of Copyable and Escapable** on the associated type is what lets `~Copyable` and `~Escapable` conformers participate. Requires the `SuppressedAssociatedTypes` experimental feature (Swift 6.3.1+).

### Methodology

Six candidate instances were examined in the 2026-04-22 experiment (lost mid-session; the variants survive in the reflection record at `swift-institute/Research/Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md`). This document replays the classification from shape analysis alone, since the experiment artifacts are gone.

| Variant | Subject | Verdict | Reason summary |
|---------|---------|---------|---------------|
| V0 | `Ownership.Borrow.\`Protocol\`` (canonical) | **FITS** | Single-param Self-projection. Default `Borrowed = Ownership.Borrow<Self>` is semantically right: "a borrow of me is a `Borrow<Me>`." |
| V1 | Hypothetical `Ownership.Mutate.\`Protocol\`` (or `Ownership.Inout.\`Protocol\``) | **FITS** | Parallel shape. `associatedtype Mutated = Ownership.Mutate<Self>`. Parameter / escapability story identical to V0. Landing when Mutate / Inout protocols ship. |
| V2 | `Property<Tag, Base>` — two-param projection | **DOES NOT FIT** | The default slot has only one axis (Self); Property's projection depends on two generic parameters. The natural shape would be `associatedtype Viewed = Property<???, Self>`, and nothing good fits `???`. Verb-namespace Tag is per-container, not per-Self. |
| V3 | Constraint-mismatch probe (Self-conformance where a constraint on the projection cannot be satisfied by Self in general) | **REFUTED** | The default N<Self> must type-check in the conforming context. If N constrains Value on something Self doesn't always satisfy, the default is rejected. Noted as a shape-level footgun; protocol authors must hold `N<Self>` against their own constraints. |
| V4 | `Hash.\`Protocol\`` — no sibling projection | **DEGENERATE** | Hash.Protocol's concern is a hash output value, not a projection of Self. There is no generic `Hash<Value>` that "is a hashed form of Value" in the ecosystem; the hash is a Cardinal. Applying the pattern would force an invented `Hash<Self>` type that doesn't correspond to anything. |
| V5 | `Storage.Contiguous` on the element axis | **DOES NOT FIT** (structurally) | `Storage.Contiguous<Element>` is parameterized over the element, not over Self. Self-projection would require `Contiguous<Self>`, but Contiguous of a container is nonsensical — the Contiguous axis is about the element, not the owning type. This failure mode is *structural* (Swift's type system would not accept the pattern expressed here), not merely *semantic*. |

### The structural / semantic precondition distinction

V5 is the variant that forced the precondition distinction into view. It's worth stating as a rule:

| Precondition | What it asserts | Failure mode if missing |
|--------------|----------------|------------------------|
| **Structural** | `Namespace.N<Self>` is a well-typed expression for any conforming Self that the protocol admits. | Swift rejects the default — the associated type declaration itself fails to type-check, or the conformance extension can't compile. |
| **Semantic** | `Namespace.N<Self>` means "a projection of Self." The projection's semantics (view, reference, borrow, inout, mutate, copy) is a relationship between an instance of Self and the projected value. | Swift accepts the default — but the meaning is wrong. Conformers get a projected type that doesn't correspond to their domain. |

V0 and V1 pass both. V2 and V5 fail the *structural* check: the generic type has the wrong arity or parameterizes on the wrong axis. V4 fails the *semantic* check: there's no projection relationship between a conformer and the hypothetical `Hash<Self>`. V3 is a family of mixed failures; each sub-case is structurally well-typed at the protocol declaration but breaks when a conformer's constraint surface doesn't subsume N's requirements.

**Rule**: a protocol can adopt the self-projection default when and only when both preconditions hold. Authors who add the default without this check risk silently degrading the conformer's experience — either failing to compile (structural) or producing the wrong semantics (semantic).

### The two-form conformer contract

Because the pattern offers a default AND permits override, conformers land in one of two shapes:

**Form A — Default-accepting conformers.** Empty extension. `Projected` resolves to `Namespace.N<Self>`. Appropriate for Value types that don't need to distinguish their projection from the generic wrapper (a simple integer, a small value-type pair, a primitive without interior storage).

```swift
extension Int32: Ownership.Borrow.`Protocol` {}
// Int32.Borrowed = Ownership.Borrow<Int32>
```

**Form B — Override conformers.** Extension + nested type declaration. `Projected` resolves to the custom type. Appropriate for types with interior storage, alignment constraints, or invariants the generic wrapper can't express. Path and String ship their own `Borrowed` structs because raw-pointer borrow semantics don't encode their normalization or null-termination invariants.

```swift
extension String: Ownership.Borrow.`Protocol` {
    public typealias Borrowed = String.Borrowed  // custom nested struct
}
```

The two forms are additive: the presence of Form-B overriders doesn't complicate Form-A defaults. Each conformer picks what fits.

### Ecosystem instances after 2026-04-24

Current state:

| Protocol | Package | Instance status | Default or override? |
|----------|---------|----------------|---------------------|
| `Ownership.Borrow.\`Protocol\`` | swift-ownership-primitives | IMPLEMENTED | Mixed — default accepted by some conformers; overridden by Path, String, and Tagged. |
| `Ownership.Mutate.\`Protocol\`` / `Ownership.Inout.\`Protocol\`` | swift-ownership-primitives (hypothetical) | NOT LANDED | Pattern pre-approved; shape parallels Borrow. |
| All other candidates (V2–V5) | various | NOT APPLICABLE | Pattern does not fit; these protocols use alternative shapes. |

Note that `Tagged: Ownership.Borrow.\`Protocol\`` (the conformance relocated to this package on 2026-04-24) uses Form B — it overrides `Borrowed = RawValue.Borrowed` rather than accepting the default `Ownership.Borrow<Tagged<Tag, RawValue>>`. This preserves wrapper transparency: `Tagged<Tag, X>.Borrowed` IS `X.Borrowed`, not a double-wrapped `Ownership.Borrow<Tagged<Tag, X>>`. The default would have been semantically wrong for the wrapper case; the override path is load-bearing.

### Relationship to the capability-lift pattern

The self-projection-default pattern and the capability-lift pattern (in `swift-carrier-primitives/Research/capability-lift-pattern.md`) are **orthogonal and composable**.

| Dimension | Self-projection default | Capability-lift |
|-----------|------------------------|-----------------|
| Protocol shape | `associatedtype X = N<Self>` | `var v: V { get }` + `init(_ v: V)` + Tagged forwarding |
| Abstracts over | A projection relationship from Self to N<Self> | A carrier relationship: bare V + Tagged<_, V> |
| Canonical instance | `Ownership.Borrow.\`Protocol\`` | `Cardinal.\`Protocol\``, `Ordinal.\`Protocol\`` |
| Works for | ~Copyable + ~Escapable single-param conformers | Copyable Underlying; Tagged forwarding |
| Super-protocol candidate? | No — the associated type default is already the shared structure | Yes — `Carrier<Underlying>` generalizes across Cardinal / Ordinal / Hash |
| Package home | swift-ownership-primitives (this research) | swift-carrier-primitives |

The two patterns are complementary: a type can participate in either, both, or neither.

| Participates in... | Example |
|--------------------|---------|
| Self-projection only | A bare value type that owns a borrowed projection but isn't a "carrier" of any other value (most Ownership.Borrow.`Protocol` conformers). |
| Capability-lift only | Cardinal / Ordinal — they're Carriers of a value but have no Self-projection (bare Cardinal is not borrowed as `Cardinal<Cardinal>`). |
| Both | A hypothetical future type that both carries a value (like Cardinal) AND projects a borrowed form (unusual; no current instance). |
| Neither | Property, Hash — Property's verb-namespace is Group B (neither pattern fits); Hash is a witness protocol orthogonal to both. |

### Provenance note — the lost 2026-04-22 doc

The original `self-projection-default-pattern.md` was authored in `swift-primitives/Research/` on 2026-04-22 with a matching experiment. Both artifacts were wiped from disk during a filesystem disturbance mid-session 2026-04-23 (see the carrier-walkback reflection). The characterization above is reconstructed from:

- The shipped `__Ownership_Borrow_Protocol` source file (the authoritative reference for the pattern's shape).
- `swift-institute/Research/Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` (V0–V5 verdicts and the structural-vs-semantic distinction).
- `swift-institute/Research/ownership-borrow-protocol-unification.md` (the IMPLEMENTED DECISION that the Borrow.Protocol shape instantiates).

The experiment has not been re-authored. If a future session wants empirical variants V0–V5 re-confirmed on Swift 6.3.1+, the experiment can be re-built from the V0 shape above — each variant is one small package probing a specific structural or semantic failure.

## Constraints

- **[PRIM-FOUND-001]** — Foundation-independent; the pattern works entirely within Swift stdlib + ecosystem primitives. No Foundation types or attributes.
- **SE-0404** — No protocol nesting inside generic structs. Forces the hoisted `__`-prefixed protocol + nested typealias workaround. Revisit if Swift evolves to permit nested-in-generic protocols.
- **SuppressedAssociatedTypes experimental feature** — Required to declare `associatedtype X: ~Copyable = N<Self>` when the default involves `~Copyable`/`~Escapable` types. Stabilization would make this pattern fully language-level.
- **Single-parameter conformer constraint** — The pattern assumes Self can be the sole axis. Two-parameter protocols (like a hypothetical `Property.\`Protocol\``) cannot use this shape; V2 rules that case out.

## Outcome

**Status**: RECOMMENDATION — characterization of a pattern already in production at its canonical instance.

### Recommendations

1. **Adopt the pattern for new protocols when both preconditions hold.** `Ownership.Mutate.\`Protocol\`` / `Ownership.Inout.\`Protocol\`` are the next likely candidates (parallel to Borrow). Any future self-projecting capability protocol in this ecosystem should follow the same shape: `associatedtype Projected = Namespace.N<Self>` with `~Copyable` + `~Escapable` suppression.

2. **Do not adopt for two-parameter projection types.** V2 showed this for Property; the same reasoning rules out any protocol whose projection depends on two generic arguments. `Property<Tag, Base>` cannot default `associatedtype Viewed = Property<???, Self>` because the Tag axis is per-container, not per-Self.

3. **Do not adopt for element-axis generics.** V5 showed this for Storage.Contiguous; the same reasoning rules out any `N<Element>` where the element axis is not "a projection of Self." Containers, buffers, and collections parameterized on element type don't fit.

4. **Do not adopt for witness protocols.** V4 showed this for Hash. Witness protocols (Hash, Equation, Comparison) abstract over operations or categorical structures, not projections. They don't have a sibling `N<Self>` that would be a "projection" of Self.

5. **Form B overrides are load-bearing for types with interior invariants.** Path, String, and Tagged all override because the default would be semantically wrong. Authors designing for the pattern should think through both forms at design time, not defer the override path to "later."

6. **The pattern composes with capability-lift without conflict.** A type that participates in both (none currently) would declare both sets of requirements without any cross-interference. Treat them as orthogonal axes.

### Queued escalations

None. The pattern is already implemented at its canonical instance, and the generalization survey has a clear negative result for the non-fitting candidates. Future decisions (Mutate.Protocol landing, Inout.Protocol landing, any new self-projecting protocol) should be checked against the structural + semantic preconditions in §"The structural / semantic precondition distinction" before committing to the shape.

## References

### Primary source

- `Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift` — the canonical instance. Authoritative for the pattern's shape.
- `Sources/Ownership Borrow Primitives/Ownership.Borrow.swift` — the generic container `Ownership.Borrow<Value>` and the nested typealias `Protocol`.

### Related research

- `swift-institute/Research/ownership-borrow-protocol-unification.md` (IMPLEMENTED, 2026-04-23) — the DECISION that produced the Borrow.Protocol shape and motivated this meta-pattern investigation.
- `swift-carrier-primitives/Research/capability-lift-pattern.md` (RECOMMENDATION, v1.1.0) — the orthogonal meta-pattern for Tagged-forwarding value carriers.
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` (RECOMMENDATION, v1.1.0) — Group A (domain-identity, capability-lift candidate) vs Group B (verb-namespace, categorically blocked). Property's Group B status explains why the self-projection default doesn't fit Property either.

### Provenance

- `swift-institute/Research/Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` — session arc that produced + lost the original doc + experiment, and later walked back the Carrier package proposal. This re-authoring restores the lost research with the surviving evidence.
- Lost: `swift-primitives/Research/self-projection-default-pattern.md` v1.0.0 (2026-04-22) — original authoring, wiped from disk mid-session 2026-04-23. Not recoverable from context.
- Lost: `Experiments/self-projection-default-pattern/` — the experiment with V0–V5 variants. Not re-authored as part of this doc; the variant verdicts are replayed from shape analysis.

### Convention sources

- **[API-IMPL-009]** — Hoisted protocol with nested typealias.
- **[PKG-NAME-002]** — `Namespace.\`Protocol\`` canonical spelling convention.
- **[MEM-COPY-*]** — `~Copyable` / `~Escapable` conformance rules that the pattern depends on.
- **[RES-020]** — Research tier rules (this doc is Tier 2).
