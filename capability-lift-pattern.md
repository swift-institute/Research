# Capability-Lift Pattern

<!--
---
version: 1.1.0
last_updated: 2026-04-22
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-22): Added §"Tagged as the canonical Carrier" — clarifies
  that Carrier IS the abstract interface that Tagged is the free/canonical
  generic implementation of (the relationship surfaced in design discussion
  asking whether Carrier and a hypothetical Tagged.`Protocol` would be
  equivalent). Sharpened Recommendation #2 in light of this. Added
  §"Worked example" with a pedagogical walkthrough of the pattern (problem,
  per-type form, super-protocol payoff). Added §"How to read this in
  practice" guide.
- v1.0.0 (2026-04-22): Initial recommendation; six experiment variants;
  Option A (refinement) vs Option B (parameterized) analysis.
-->

## Context

`swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift`
and `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift`
both implement a **capability-lift pattern**: a concrete value type V
(`Cardinal`, `Ordinal`) is paired with a hoisted-style protocol
`V.\`Protocol\`` that abstracts the value's role. Bare V conforms with
`Domain = Never`; `Tagged<Tag, V>` conforms conditionally with
`Domain = Tag`. APIs declared in terms of `some V.\`Protocol\`` accept
both forms transparently.

The user's design framing: **value types are primary; protocols are
additive.** Cardinal/Ordinal are concrete in normal use; their
`.\`Protocol\`` forms exist so APIs can opt into broader acceptance
without forcing the per-type accessor through every Tagged wrapper.
The protocols and the value types coexist deliberately.

The pattern is currently authored separately for each value type. This
document characterizes the pattern's recipe and explores how far it
generalizes — specifically, whether a SUPER-protocol can factor out
the shared structure shared by `Cardinal.\`Protocol\``,
`Ordinal.\`Protocol\``, and adjacent ecosystem instances.

The empirical work lives in
`swift-primitives/Experiments/capability-lift-pattern/`
(CONFIRMED on Apple Swift 6.3.1, 2026-04-22).

**Trigger**: [RES-012] Discovery — proactive characterization of an
ecosystem-recurring pattern, prompted by user observation that
`Ordinal.\`Protocol\`` and `Cardinal.\`Protocol\`` "share an abstract
thing." This document names that thing and analyses two unification
options.

**Scope**: Cross-package — the candidates examined span
swift-cardinal-primitives, swift-ordinal-primitives, swift-hash-primitives,
and swift-identity-primitives' Tagged. The findings inform any future
adoption of the *.\`Protocol\` pattern at the primitives layer.
[RES-002a]

**Tier**: 2 (Standard) — cross-package, characterizes a pattern that
will inform future primitives. Not tier 3 because the document does
not establish a normative semantic contract; it characterizes options.
[RES-020]

**Relationship to prior research**: this document is *complementary
to and orthogonal from* the **self-projection default pattern**
characterized in
`swift-primitives/Research/self-projection-default-pattern.md`. The
self-projection pattern (Borrow / Mutate family) addresses a single
associatedtype defaulting to `N<Self>`. The capability-lift pattern
addresses Tagged-forwarding capability protocols over a value-type V.
A type may participate in either, both, or neither — see §"Pattern
taxonomy" below.

## Question

Given the recipe shared by `Cardinal.\`Protocol\`` and `Ordinal.\`Protocol\``,
three sub-questions:

1. **What's the shared abstract structure?** State the recipe
   precisely so it can be reproduced for other value types.

2. **Can a SUPER-protocol factor out the recipe?** Specifically, can
   the shared structure (Domain associatedtype + value accessor +
   round-trip init + Tagged forwarding) be expressed as a protocol
   that per-type protocols refine, OR as a parameterized protocol
   (`Carrier<Underlying>`) that types directly conform to?

3. **What does the pattern enable, and where does it break?** What
   APIs become writable that were not, and what shapes (~Copyable
   Underlying, generic Underlying, existentials) strain or break the
   pattern?

## Worked example: what is the pattern, and how is it used?

This section grounds the analysis in a concrete walkthrough. Skip it
if you've internalized the pattern from Cardinal/Ordinal already.

### The problem the pattern solves

Suppose you have `Cardinal` and several Tagged-wrapped variants:

```swift
typealias ByteCount      = Tagged<Bytes,  Cardinal>
typealias FrameCount     = Tagged<Frames, Cardinal>
typealias Index<E>.Count = Tagged<E,      Cardinal>
```

You want to write `align(_:)`. Without the pattern:

```swift
func align(_ c: Cardinal) -> Cardinal {
    Cardinal((c.raw + 7) & ~7)
}

// Doesn't accept ByteCount. You'd need either an overload per Tag
// (impossible to enumerate) or unwrapping at every call site
// (defeats the phantom typing).
```

The pattern's job: **let `align` accept anything that "is" a Cardinal —
bare or Tagged — without the call site giving up its phantom type.**

### The per-type pattern (today's Cardinal.\`Protocol\`)

The recipe is in §"The recipe" below. Once `Cardinal.\`Protocol\``
is in place, `align` becomes:

```swift
func align<C: Cardinal.`Protocol`>(_ c: C) -> C {
    C(Cardinal((c.cardinal.raw + 7) & ~7))
}

let a: Cardinal   = align(Cardinal(13))           // returns Cardinal
let b: ByteCount  = align(ByteCount(.init(13)))   // returns ByteCount — phantom preserved
let c: FrameCount = align(FrameCount(.init(13)))  // returns FrameCount — phantom preserved
```

The key move: `init(_ cardinal: Cardinal)` is the phantom-preserving
reconstructor. When `align` returns `C(Cardinal(aligned))`, Swift
dispatches to the conformer's init — which knows how to wrap the value
with its original Tag.

### What's missing — and what the super-protocol adds

You can write `align` for any Cardinal-shaped carrier, and `next` for
any Ordinal-shaped carrier. But you cannot write a function that
works for *any carrier of any type at all* — there's no protocol that
abstracts "is a Carrier" without committing to a specific Underlying.

That's what the super-protocol fixes:

```swift
public protocol Carrier<Underlying> {
    associatedtype Domain: ~Copyable
    associatedtype Underlying
    var underlying: Underlying { get }
    init(_ underlying: Underlying)
}
```

Now you can write APIs at three levels of specificity:

```swift
// Specific (current): Cardinal-shaped only.
func align<C: Cardinal.`Protocol`>(_ c: C) -> C { ... }

// Specific via Carrier (cleaner spelling): same set, parameterized form.
func align(_ c: some Carrier<Cardinal>) -> Cardinal { ... }

// Fully generic — only enabled by the super-protocol.
// Works for ANY carrier — Cardinal-shaped, Ordinal-shaped, future shapes.
func describe<C: Carrier>(_ c: C) -> String {
    "Carrier of \(C.Underlying.self) with Domain \(C.Domain.self)"
}

describe(Cardinal(7))                          // "Carrier of Cardinal with Domain Never"
describe(ByteCount(.init(7)))                  // "Carrier of Cardinal with Domain Bytes"
describe(Ordinal(5))                           // "Carrier of Ordinal with Domain Never"
describe(Index<Buffer>(.init(.init(5))))       // "Carrier of Ordinal with Domain Buffer"
```

The fully-generic form is the super-protocol's payoff. Concrete
near-term uses:

- **Diagnostics**: error messages that include the phantom Domain
  ("expected `Index<File>` Count, got `Index<Buffer>` Count") without
  per-type plumbing.
- **Cross-Carrier conversion**: `func reroot<C1: Carrier, C2: Carrier>(_ c: C1) -> C2 where C1.Underlying == C2.Underlying`
  — change phantom Tag while preserving value.
- **Serialization / witness scaffolding**: one Carrier-aware codec
  generates per-type code from the Underlying, instead of N hand-
  written codecs.
- **Reflection over typed indices**: print or compare phantom types
  in panics, logs, asserts.

## Analysis

### Methodology

Six variants authored at
`Experiments/capability-lift-pattern/Sources/main.swift`. Stubs (not
real ecosystem types) are used so that super-protocol unifications
can be proposed without modifying production code. Variant verdicts:

| Variant | Subject | Verdict |
|---------|---------|---------|
| V0 | Cardinal-shape per-type baseline | **FITS** (CONFIRMED) |
| V1 | Ordinal-shape per-type baseline with refinement (Count → Cardinal.`Protocol`) | **FITS** (CONFIRMED) |
| V2 | Super-protocol via REFINEMENT (`Carrier.\`Protocol\`` with assoctype Underlying; per-type protocols refine `where Underlying == X`) | **FITS** (CONFIRMED) — with dual-accessor cost |
| V3 | Super-protocol via PARAMETERIZATION (SE-0346 primary associated type; `Carrier<Underlying>`) | **FITS** (CONFIRMED) — strictly more flexible |
| V4 | API broadening at four levels (per-type, refinement, parameterized, fully generic) | **FITS** (CONFIRMED) — all forms accept bare + Tagged |
| V5 | Limits (generic Underlying, ~Copyable Underlying, existential `any`) | **PARTIAL** — three sub-cases catalogued |

### The recipe (shared structure)

Every per-type instance of the pattern follows this recipe:

```swift
// 1. The concrete value type V.
public struct V { ... }

// 2. The capability protocol V.`Protocol`.
extension V {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable        // Never for bare V; Tag for Tagged
        var v: V { get }                        // value accessor
        init(_ v: V)                            // round-trip
    }
}

// 3. Self-conformance: bare V is its own carrier.
extension V: V.`Protocol` {
    public typealias Domain = Never
    public var v: V { self }
    public init(_ v: V) { self = v }
}

// 4. Tagged forwarding: phantom Tag becomes Domain.
extension Tagged: V.`Protocol`
where RawValue == V, Tag: ~Copyable {
    public typealias Domain = Tag
    public var v: V { rawValue }
    public init(_ v: V) { self.init(__unchecked: (), v) }
}

// 5. Operators / methods on the protocol — lifts to all conformers.
extension V.`Protocol` {
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(V(lhs.v.raw + rhs.v.raw))
    }
}
```

**Refinement variant** (Ordinal): adds `associatedtype Count: Cardinal.\`Protocol\``,
which lets the operator extension consume a Count-typed argument that
preserves phantom typing (`Tagged<Tag, Ordinal>.Count = Tagged<Tag, Cardinal>`).

### Tagged as the canonical Carrier

A natural design question: is `Carrier<Underlying>` equivalent to a
hypothetical `Tagged<A, B>.\`Protocol\``? Strictly NO — Carrier is
broader. Spiritually YES — they describe the same projection, with
Tagged as the canonical generic implementation.

**Why not strictly equivalent**: a hypothetical `Tagged<A, B>.\`Protocol\``
(hoisted per SE-0404 since Tagged is generic) would describe "things
that are Tagged-shaped":

```swift
public protocol __TaggedProtocol {
    associatedtype Tag                       // phantom
    associatedtype RawValue
    var rawValue: RawValue { get }
    init(__unchecked: Void, _ rawValue: RawValue)
}
```

Conformers: `Tagged<A, B>` and structurally identical types. **Bare
`Cardinal` doesn't conform** — it has no `__unchecked:` init, no
phantom Tag.

`Carrier<Underlying>` accepts the bare Cardinal case via `Domain = Never`:

```swift
extension Cardinal: Carrier {
    typealias Domain = Never
    typealias Underlying = Cardinal
    var underlying: Cardinal { self }
    init(_ underlying: Cardinal) { self = underlying }
}
```

That `Domain = Never` row is the wedge. It's the case Tagged.\`Protocol\`
can't naturally express — bare Cardinal isn't tagged, so it can't
conform to a Tagged-shaped protocol. Carrier handles it because "no
phantom" is just a degenerate kind of phantom.

**Why deeply related anyway**: strip away the bare-Cardinal case and
the two collapse. The (Tag, RawValue) → (Domain, Underlying) renaming
is the only structural difference, and that's cosmetic. **Carrier IS
the abstract interface that abstracts Tagged-style wrapping; Tagged is
the canonical generic implementation.**

The relationship is the same shape as:

| Abstract interface | Canonical generic implementation |
|--------------------|----------------------------------|
| `Sequence` | `Array<T>` (any T → free Sequence of T) |
| Optional-like | `Optional<T>` (any T → free nullable T) |
| `Carrier` | `Tagged<Tag, V>` (any (Tag, V) → free Carrier with Domain=Tag, Underlying=V) |

So Tagged can be read two ways:

| As a... | What it is |
|---------|------------|
| Concrete struct | A 2-param phantom-typed wrapper |
| Generic constructor | The function `(Tag, V) → Carrier<V>` |

The second reading is what makes Tagged the universal Carrier-builder.
**Anywhere you'd want a Carrier with a specific Domain, you reach for
Tagged.** You don't author a custom Carrier conformance for a new
phantom Tag; you instantiate `Tagged<MyTag, MyValue>` and the
conformance comes free via the parametric extension.

Bare types (Cardinal, Ordinal) conform separately as "trivial Carriers"
— Domain is Never, the value is itself. They don't go through Tagged
because they don't need a phantom. But they participate in the same
protocol so APIs accept both.

**Implications**:

1. **Don't introduce both `Tagged.\`Protocol\`` and `Carrier`.** They
   describe overlapping sets with the bare-self case as the only
   difference. Carrier is the more useful name because it includes
   both forms uniformly.

2. **The `Domain = Never` self-conformance trick is doing real work.**
   It's how a value type joins the Carrier club without going through
   Tagged. Without it, you'd force Cardinal to be
   `Tagged<NeverTag, Cardinal>` everywhere — awkward and pointless.

3. **A new value type V joins the family in two extensions**, not one:
   - `extension V: Carrier where Underlying == V` (V carries itself —
     trivial Carrier, Domain = Never)
   - `extension Tagged: Carrier where RawValue == V, Tag: ~Copyable`
     (Tagged generates Carriers of V for any Tag)

   Together: V plus all its Tagged variants are a Carrier-of-V. APIs
   taking `some Carrier<V>` accept the union.

4. **The shape generalizes beyond Tagged-as-storage.** A future
   heap-allocated wrapper, a SmallVec-style storage, anything with a
   (phantom domain, underlying value) pair — could conform. Carrier
   doesn't commit to Tagged's storage; it commits to the projection.
   Tagged is the canonical implementation but not the only one.

### Existing ecosystem instances

A grep confirms the following types currently follow this recipe (at
varying levels of completeness):

| Type | File | Refines? | Tagged forwarding? |
|------|------|---------|--------------------|
| `Cardinal.\`Protocol\`` | `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift:29` | — | yes (line 65) |
| `Ordinal.\`Protocol\`` | `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift:35` | `Count: Cardinal.\`Protocol\`` | yes (line 80) |
| `Hash.\`Protocol\`` | `swift-hash-primitives/Sources/Hash Primitives Core/Hash.Protocol.swift:51` | `Equation.\`Protocol\`` | yes via `Hash.Protocol+Identity.Tagged.swift` |

Additional candidates with structurally similar shape (not all carry
the explicit `Domain` associatedtype, so adoption would require extension):
`Equation.\`Protocol\``, `Comparison.\`Protocol\``, `Numeric.\`Protocol\``.

### Option A: Super-protocol via REFINEMENT (V2)

Define a super-protocol `Carrier.\`Protocol\`` with the shared
structure; per-type protocols refine it.

```swift
public enum Carrier {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable
        associatedtype Underlying       // the carried value type
        var underlying: Underlying { get }
        init(_ underlying: Underlying)
    }
}

extension V {
    public protocol `Protocol`: Carrier.`Protocol` where Underlying == V {
        var v: V { get }                // per-type accessor (defaults to underlying)
    }
}

extension V.`Protocol` {
    public var v: V { underlying }      // default — eliminates conformer-side duplication
}
```

**Empirical verdict (V2)**: COMPILES. Generic algorithms can dispatch
on `Carrier.\`Protocol\`` uniformly without naming the per-type
protocol; per-type accessor name preserved via the protocol-extension
default.

**Costs**:

1. **Tagged conformance must be authored twice**: when Tagged conforms
   to a refinement `V.\`Protocol\``, Swift's diagnostic explicitly
   says *"conditional conformance to a protocol does not imply
   conformance to its inherited protocol."* The Tagged extension must
   first conform Tagged to `Carrier.\`Protocol\`` with the same
   bounds, THEN conform Tagged to `V.\`Protocol\`` (which has no new
   requirements once the parent is satisfied). Two extensions with
   identical bounds replace one.

2. **Dual-accessor surface**: conformers see both `underlying` (from
   the super-protocol) and `v` (from the per-type protocol). The
   default elides the IMPLEMENTATION duplication, but consumers can
   spell either form at use sites — a minor coherence issue.

3. **Underlying associatedtype is observable**: `C.Underlying` is
   accessible everywhere `C: Carrier.\`Protocol\``. For per-type
   APIs that don't care about the abstraction, this is dead surface
   area on the protocol.

### Option B: Super-protocol via PARAMETERIZATION (V3)

SE-0346 (Lightweight same-type requirements for primary associated
types) ships in Swift 6.3, enabling:

```swift
public protocol Carrier<Underlying> {
    associatedtype Domain: ~Copyable
    associatedtype Underlying
    var underlying: Underlying { get }
    init(_ underlying: Underlying)
}
```

API sites then read:

```swift
func align(_ c: some Carrier<Cardinal>) -> Cardinal { ... }
func nextIndex(_ o: some Carrier<Ordinal>) -> Ordinal { ... }
```

**Empirical verdict (V3)**: COMPILES. No intermediary `V.\`Protocol\``
is required — types conform directly to `Carrier`, and API sites use
parameterized constraints.

**Strictly-more-flexible properties relative to Option A**:

- **No per-type protocol needed at all**: `Carrier<Cardinal>` IS the
  API constraint. Per-type protocols become an OPT-IN addition (e.g.,
  via an extension on `Carrier where Underlying == Cardinal`),
  not a refinement requirement.
- **Single Tagged conformance**: only one extension per RawValue type;
  no double-conformance dance.
- **Cleaner API site spelling**: `some Carrier<Cardinal>` reads as
  one constraint instead of `some Cardinal.\`Protocol\``.

**Tradeoffs**:

- **Loss of per-type accessor name**: `c.cardinal` becomes
  `c.underlying` at API sites unless reintroduced via
  `extension Carrier where Underlying == Cardinal { var cardinal: Cardinal { underlying } }`.
  This extension can coexist; users can write either name.
- **Loss of namespace anchoring**: `some Carrier<Cardinal>` doesn't
  visually anchor to the Cardinal namespace the way
  `some Cardinal.\`Protocol\`` does. For discoverability, Cardinal-
  related extensions still want to live in the Cardinal namespace.

### Option C: Both — parameterized super-protocol AND per-type typealias

The two options are not mutually exclusive. The cleanest combination:

```swift
// Super-protocol, parameterized.
public protocol Carrier<Underlying> {
    associatedtype Domain: ~Copyable
    associatedtype Underlying
    var underlying: Underlying { get }
    init(_ underlying: Underlying)
}

// Per-type typealias (NOT a refinement) for namespace anchoring.
extension V {
    public typealias `Protocol` = Carrier where Underlying == V
        // (typealias-with-where-clause requires careful spelling;
        //  alternatively, a constrained-existential typealias if
        //  needed at use sites)
}

// Per-type accessor name via constrained extension.
extension Carrier where Underlying == V {
    public var v: V { underlying }
}
```

This gives three names for the same constraint:
`some Carrier<V>` (parameterized form), `some V.\`Protocol\`` (namespace-
anchored alias), `some V` (when no genericity needed). Authors can
pick the one that reads best at each call site.

**Note on `typealias` syntax**: Swift does not currently allow
`typealias X = Y where Z` directly; the equivalent is achieved via a
parameterized constrained existential (`any Carrier<V>`) or via a
constrained protocol extension. Production adoption of Option C
would need to test which spellings the compiler accepts; the
experiment did not exhaust the typealias variants.

### API-broadening surface (V4)

Four function signatures, all accepting the same conformer set
(bare `V` and any `Tagged<Tag, V>`):

```swift
// Form A: per-type protocol.
func align<C: V.`Protocol`>(_ c: C) -> C { ... }

// Form B: super-protocol via refinement.
func align<C: V.`Protocol`>(_ c: C) -> C { ... }    // identical at the use-site
                                                     // (super-protocol is implied)

// Form C: parameterized super-protocol.
func align(_ c: some Carrier<V>) -> V { ... }

// Form D: fully generic — operates on ANY Carrier.
func describe<C: Carrier>(_ c: C) -> String {
    "Carrier of \(C.Underlying.self)"
}
```

Forms A–C accept the same set; differences are ergonomic. Form D is
**only enabled by a super-protocol** — Option A's refinement and
Option B's parameterization both support it, but per-type-only
protocols cannot express "any Carrier of any type."

The most important enablement is Form D: cross-Carrier algorithms
become writable. Concrete near-term applications:

- **Phantom-type-aware reflection**: `func describePhantomType<C: Carrier>(_ c: C) -> String`
  — useful for debug logs, error messages, panic dumps.
- **Witness conformance for serialization / hashing**: a single
  Carrier-aware hash function works across Cardinal, Ordinal, and
  any future participant.
- **Generic conversion utilities**: `func reroot<C1: Carrier, C2: Carrier>(_ c: C1) -> C2 where C1.Underlying == C2.Underlying`.

### Limits (V5)

Three failure / strain modes catalogued:

#### V5a — Generic Underlying

Conforming a generic type (e.g., `OptCardinal<C>`) to `Carrier<Self>`
works structurally. The complication: Tagged conformance is
per-`OptCardinal<T>`, not parameterizable over T:

```swift
extension Tagged: Carrier
where RawValue == OptCardinal<UInt> { ... }   // works
extension Tagged: Carrier
where RawValue == OptCardinal<T> { ... }      // NOT POSSIBLE — T isn't bound
```

**Implication**: each T-instantiation of a generic Underlying needs
its own Tagged conformance. For widely-instantiated generics
(`Optional<T>`, `Result<T, E>`), this would be O(N) extensions in N
instantiations.

#### V5b — ~Copyable Underlying

The recipe assumes `Copyable` Underlying because:

1. `var underlying: Underlying { get }` requires copying for the get.
   For ~Copyable Underlying, must use `borrowing get`.
2. `init(_ underlying: Underlying)` is by-value copy. For ~Copyable,
   must use `consuming` semantics.

A ~Copyable variant of the protocol compiles:

```swift
public protocol NoncopyCarrier: ~Copyable {
    associatedtype Domain: ~Copyable
    associatedtype Underlying: ~Copyable
    var underlying: Underlying { borrowing get }
    init(_ underlying: consuming Underlying)
}
```

But the **round-trip property is broken**: after `init(_ underlying:)`,
the Underlying is consumed — there is no original to compare against.
The "carrier" abstraction (a thing that carries an Underlying you can
extract again) only fully holds for Copyable Underlying. For ~Copyable,
the abstraction is closer to "a wrapper that takes ownership and lets
you inspect via borrow."

**Implication**: don't extend the same Carrier protocol to ~Copyable
Underlying. Two distinct protocols (Carrier for Copyable, NoncopyCarrier
for ~Copyable) are clearer than one with `~Copyable` suppressions.

#### V5c — Existentials (`any Carrier`)

`any Carrier`-typed values compile and erase the Underlying type to
`Any`. The protocol's value is at the GENERIC dispatch level
(`some Carrier<X>`), not at the existential level. Functions taking
`any Carrier` cannot extract the Underlying type without opening the
existential first.

**Implication**: the pattern is generic-friendly, not existential-
friendly. Document this in the Carrier protocol's API guidance.

### Pattern taxonomy

The *.\`Protocol\` family in the ecosystem decomposes into three
distinct, COMPOSABLE patterns:

| Pattern | What it adds | Examples | This doc |
|---------|--------------|----------|----------|
| (a) Per-type capability protocol with Tagged forwarding | `V.\`Protocol\`` lets APIs accept bare V + Tagged<_, V> | Cardinal, Ordinal, Hash | Recipe in §"The recipe" |
| (b) Carrier super-protocol (refinement OR parameterized) | Cross-V generic algorithms; uniform reflection | Proposed by V2 / V3 | §"Option A" / §"Option B" |
| (c) Self-projection default | A protocol's associatedtype defaults to `N<Self>` | Borrow/Mutate (DECISION) | `Research/ownership-borrow-protocol-unification.md` |

**Composition**: a type may participate in:

- **(a) only** — current Cardinal.\`Protocol\` state
- **(a) + (b)** — Cardinal refines Carrier; cross-type algorithms become writable
- **(a) + (c)** — a value type with a Self-projecting view (rare; would require V to also have a generic struct V<Value>)
- **All three** — an ambitious adoption, would require the value type to be both a Carrier AND a self-projection target

The patterns are NOT redundant with each other; they address different
problems. The self-projection default pattern's Borrow case has no
"Underlying" concept — Borrow IS the projection, not a carrier of one.
Conversely, Cardinal has no `N<Self>` projection — it carries a value,
it doesn't project Self.

## Outcome

**Status**: RECOMMENDATION — characterizes the pattern's structure
and unification options; does NOT prescribe ecosystem-wide adoption
of any super-protocol. Adoption decisions remain with the principal,
informed by this characterization.

### Recommendations (informed by V0–V5)

1. **Adopt Option B (parameterized super-protocol) over Option A (refinement)
   if a super-protocol is introduced.** V3 demonstrates that SE-0346's
   parameterized form is strictly more flexible than V2's refinement —
   no double-conformance dance for Tagged, cleaner API site spelling,
   and Form-D fully generic algorithms work the same way.

2. **Don't introduce both `Carrier` and a hypothetical `Tagged.\`Protocol\``.**
   Per §"Tagged as the canonical Carrier", they describe overlapping
   sets with the bare-self case as the only difference. Carrier is the
   more useful name because it captures both bare and Tagged forms
   uniformly, with Tagged as the canonical generic implementation.

3. **Don't make `V.\`Protocol\`` a refinement of Carrier.** If both
   forms are wanted (per-type accessor name AND super-protocol
   dispatch), use Option C — parameterized Carrier with a constrained
   extension reintroducing the per-type accessor name. Refinement
   adds the double-conformance Tagged cost for no compensating benefit.

4. **Don't extend Carrier to ~Copyable Underlying.** V5b shows the
   round-trip property breaks (init consumes; nothing left to
   re-extract). Author a separate `NoncopyCarrier` if/when needed.

5. **Cardinal/Ordinal don't need to change today.** The per-type
   pattern (V0/V1) works. A Carrier super-protocol can be ADDED
   later without breaking existing APIs — `Cardinal.\`Protocol\``
   becoming a constrained extension on `Carrier where Underlying == Cardinal`
   is a one-extension migration. The decision to add Carrier should be
   driven by demand for Form-D generic algorithms (cross-Carrier
   reflection, diagnostics, conversion), not by a desire to factor
   for its own sake.

6. **Audit Hash.\`Protocol\`, Equation.\`Protocol\`, and similar for
   recipe completeness — but don't sweep them into Carrier wholesale.**
   They follow a similar shape (capability protocol + Tagged forwarding)
   but their *role* differs: Hash is "I produce a hash", Comparison
   is "I am orderable". Same recipe, different semantics. The Carrier
   abstraction belongs to the value-CARRYING subset (Cardinal, Ordinal,
   maybe future Time/Distance/etc.); witness protocols (Hash, Comparison)
   stay distinct.

### How to read this in practice

| If you're... | The right form is... |
|--------------|----------------------|
| Writing an API for `Cardinal` quantities | `func f<C: Cardinal.\`Protocol\`>(_ c: C) -> C` (today) or `func f(_ c: some Carrier<Cardinal>) -> Cardinal` (if Carrier added) |
| Writing an API for `Ordinal` positions | Mirror of above with `Ordinal` |
| Writing a function that should accept ANY Carrier (debug, log, generic conversion) | `func f<C: Carrier>(_ c: C) -> ...` — only works after Carrier exists |
| Adding a new Tag for an existing value type V | Just `typealias MyCount = Tagged<MyTag, V>`. Conformance to `V.\`Protocol\`` (and Carrier, if added) comes free via the parametric extension |
| Adding a new value type V to the Carrier family | Two extensions: `extension V: Carrier where Underlying == V` (trivial Carrier) AND `extension Tagged: Carrier where RawValue == V, Tag: ~Copyable` (Tagged generates Carriers of V for any Tag) |
| Adding a `~Copyable` value type | Don't conform to Carrier — author a separate NoncopyCarrier protocol |
| Writing an existential `any Carrier<X>` | Type-checks but loses Underlying; prefer `some Carrier<X>` for generic dispatch |

### What the document does NOT do

- Propose adopting a Carrier super-protocol in production.
- Modify any existing protocol (Cardinal.\`Protocol\`, Ordinal.\`Protocol\`,
  Hash.\`Protocol\`).
- Survey ecosystem candidates beyond the three named (Cardinal, Ordinal,
  Hash). The grep targets surfaced ~11 hoisted-protocol typealias
  sites; only the candidates relevant to the capability-lift
  question were probed.
- Prescribe naming. "Carrier" is the working name from the experiment;
  alternatives ("Lifted", "Witnessing", "Underlying", "Wrapping")
  are equally defensible.

### Queued escalations

None. The investigation surfaced no shape that would warrant principal
input beyond the choice of whether and when to introduce a Carrier
super-protocol — which is the principal's call, not the
investigation's.

## References

### Primary sources

- **Experiment (CONFIRMED)**: `swift-primitives/Experiments/capability-lift-pattern/Sources/main.swift` (Apple Swift 6.3.1, 2026-04-22) — six variants V0–V5 probing the capability-lift pattern's recipe, super-protocol unification options, API broadening, and limits.
- **Companion research (RECOMMENDATION)**: `swift-primitives/Research/self-projection-default-pattern.md` (v1.0.0, 2026-04-22, tier 2) — characterizes the orthogonal self-projection pattern from the Borrow DECISION.
- **Reference DECISION**: `swift-primitives/Research/ownership-borrow-protocol-unification.md` (v1.0.0, 2026-04-22, tier 2) — the Borrow case that motivated the broader meta-pattern investigation.

### Ecosystem instances (real types matching the recipe)

- `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` — Cardinal.`Protocol`, line 29; Tagged forwarding, line 65.
- `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift` — Ordinal.`Protocol` with Count refinement, line 35; Tagged forwarding, line 80.
- `swift-hash-primitives/Sources/Hash Primitives Core/Hash.Protocol.swift` — Hash.`Protocol`, line 51.
- `swift-hash-primitives/Sources/Hash Primitives/Hash.Protocol+Identity.Tagged.swift` — Hash Tagged forwarding.

### Convention sources

- **[PKG-NAME-002]**: canonical capability protocol = `Namespace.\`Protocol\``; gerund typealias rules.
- **[API-IMPL-009]**: hoisted protocol with nested typealias pattern.
- **[RES-020]**: research tier rules.
- **[EXP-006b]**: confirmation evidence requirements.

### Language references

- **SE-0346 (Lightweight same-type requirements for primary associated types)** — enables Option B's `Carrier<Underlying>` parameterized form. Shipped in Swift 5.7+; available in 6.3.
- **SE-0309 (Unlock existentials for all protocols)** — relevant to V5c's `any Carrier` analysis.
- **SE-0353 (Constrained Existential Types)** — `any Carrier<Cardinal>` form.
- **Swift 6.3.1 experimental features required**: `Lifetimes`, `SuppressedAssociatedTypes` (the second is needed for the `Domain: ~Copyable` associatedtype suppression).
