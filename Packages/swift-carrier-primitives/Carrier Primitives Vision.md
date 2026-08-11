# Carrier Primitives — Vision

<!--
---
version: 1.0.0
last_updated: 2026-04-29
status: VISION
tier: 2
scope: package-specific
audience: contributor
supersedes:
  - capability-lift-pattern.md (v1.3.0, RECOMMENDATION, 2026-04-26)
  - capability-lift-pattern-primitives.md (v1.2.0, RECOMMENDATION, 2026-04-23)
  - capability-lift-pattern-academic-foundations.md (v1.0.0, ANALYSIS, 2026-04-23)
  - capability-lift-pattern-academic-foundations-primitives.md
  - carrier-vs-rawrepresentable-comparative-analysis.md (v1.0.0, DECISION, 2026-04-24)
  - cross-carrier-utilities.md (v1.0.0, RECOMMENDATION, 2026-04-26)
  - dynamic-member-lookup-decision.md (v1.0.0, DECISION, 2026-04-25)
  - generic-consumer-across-quadrants.md (v1.0.0, REFERENCE, 2026-04-24)
  - mutability-design-space.md (v1.1.0, DECISION, 2026-04-25)
  - round-trip-semantics-noncopyable-underlyings.md (v1.0.0, DECISION, 2026-04-24)
---
-->

> **Audience**: contributors and ecosystem maintainers. This document
> consolidates the package's design rationale — the WHY behind 0.1.0's
> shape. Consumer-facing usage is in the DocC catalog
> (`Sources/Carrier Primitives/Carrier Primitives.docc/`); this document
> is contributor-facing per `[DOC-101]`'s consumer/contributor boundary.

## Executive summary

`Carrier<Underlying>` is the swift-carrier-primitives super-protocol for
phantom-typed value wrappers. It abstracts the structural pattern shared
by `Cardinal`, `Ordinal`, `Hash.Value`, `Tagged<Tag, RawValue>`,
`Affine.Discrete.Vector`, `Property<Tag, Base>`, and the ~80 ecosystem
typealias sites that the cascading `Tagged: Carrier where RawValue:
Carrier` extension lifts automatically into the family.

**What ships at v0.1.0**:

- The protocol itself — two associated types (`Domain`, `Underlying`),
  two members (`var underlying: Underlying { borrowing get }`,
  `init(_ underlying: consuming Underlying)`), all under `~Copyable,
  ~Escapable` suppression so the protocol covers all four
  `Copyable × Escapable` quadrants of both Self and Underlying.
- Four trivial-self-Carrier defaults — `extension Carrier where
  Underlying == Self` plus three quadrant-specialised variants.
- 28 stdlib-integration conformances (Bool, Character, all integer
  families, floating-point families, String/Substring/StaticString,
  Span / RawSpan / MutableSpan / MutableRawSpan, Duration,
  ObjectIdentifier, Never, Unicode.Scalar) as trivial self-carriers.

**What is deferred**:

- Cross-Carrier utility methods (`describe`, `reroot`, `equate`,
  `project`, conditional stdlib conformances). All seven candidates
  surveyed lack a credible second consumer per [RES-018].
- A `Carrier.Mutable` refinement or sibling. Mutation is per-conformer
  concrete API; `init(_:)` reconstruction is the canonical generic
  channel. A future orthogonal `Mutatable` protocol in a separate
  package remains an option but the focused investigation has
  DEFERRED.
- `@dynamicMemberLookup` — asymmetric across the four quadrants
  (Q1 only via stdlib KeyPath constraints), so uniform-absence is
  cleaner than partial-availability.

**What Carrier deliberately does NOT do**:

- Refine or replace `Swift.RawRepresentable` — non-substitutable
  design spaces.
- Subsume per-type capability protocols (Cardinal.\`Protocol\`,
  Ordinal.\`Protocol\`, Hash.\`Protocol\`). Those stay as siblings,
  not refinements.
- Carry stdlib integrations (Codable, OptionSet, auto-derivation).
  The ecosystem is responsible; stdlib is unaware.

The rest of this document explains why each of those choices is the
considered position — the load-bearing claims, the empirical
verifications, and the academic and cross-language grounding behind
them.

---

## Part 1 — The problem

### Phantom-typed wrappers as ecosystem currency

The swift-primitives ecosystem makes heavy use of phantom-typed value
wrappers — types where a type parameter (the "phantom") does not appear
in any field, but discriminates otherwise-identical values at the type
level:

```swift
extension User  { typealias ID    = Tagged<User,  UInt64>   }
extension Order { typealias ID    = Tagged<Order, UInt64>   }
extension Byte  { typealias Count = Tagged<Byte,  Cardinal> }
extension Frame { typealias Count = Tagged<Frame, Cardinal> }
extension Index { typealias Count = Tagged<Element, Cardinal> }
```

`User.ID` and `Order.ID` are both `UInt64` at runtime. The phantom `User`
and `Order` make them distinct types so a function expecting a `User.ID`
cannot be called with an `Order.ID`. The discrimination is purely
compile-time; there is zero runtime cost.

This pattern recurs everywhere. The ecosystem ships hundreds of such
types. The question is: what abstract interface do they share?

### The pre-Carrier landscape

Before Carrier, each value type that wanted to be both bare and
Tagged-wrappable had to ship its own per-type capability protocol —
the **capability-lift pattern**:

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

`align(_:)` over `Cardinal.\`Protocol\`` then accepts bare `Cardinal`
AND every `Tagged<Tag, Cardinal>` variant without giving up phantom
typing at the call site:

```swift
func align<C: Cardinal.`Protocol`>(_ c: C) -> C {
    C(Cardinal((c.cardinal.raw + 7) & ~7))
}

let a: Cardinal    = align(Cardinal(13))             // bare Cardinal
let b: Byte.Count  = align(Byte.Count(.init(13)))    // phantom preserved
let c: Frame.Count = align(Frame.Count(.init(13)))   // phantom preserved
```

The recipe works. The ecosystem ships it for `Cardinal.\`Protocol\``,
`Ordinal.\`Protocol\``, `Hash.\`Protocol\``, and
`Affine.Discrete.Vector.\`Protocol\``. Each per-type protocol can be
authored independently.

### What the per-type pattern cannot express

You can write `align` for any Cardinal-shaped carrier, and `next` for
any Ordinal-shaped carrier. But you cannot write a function that
operates on **any carrier of any type at all**. There is no protocol
abstracting "is a carrier" without committing to a specific
`Underlying`.

That's the gap Carrier fills. Form-D (a name from
`capability-lift-pattern.md` §"API broadening surface") is the
fully-generic dispatch shape:

```swift
func describe<C: Carrier>(_ c: C) -> String {
    "Carrier of \(C.Underlying.self) with Domain \(C.Domain.self)"
}

describe(Cardinal(7))                          // "Carrier of Cardinal with Domain Never"
describe(Byte.Count(.init(7)))                 // "Carrier of Cardinal with Domain Byte"
describe(Ordinal(5))                           // "Carrier of Ordinal with Domain Never"
describe(Index<Buffer>(.init(.init(5))))       // "Carrier of Ordinal with Domain Buffer"
```

The fully-generic form is the super-protocol's payoff. It enables:

- **Phantom-aware diagnostics** — error messages, panics, log entries
  that include the phantom Domain ("expected Index<File> count, got
  Index<Buffer> count") without per-type plumbing.
- **Cross-Carrier conversion** — `func reroot<C1, C2>(...)` to change
  phantom Tag while preserving Underlying value.
- **Witness scaffolding for serialization / hashing** — one Carrier-
  aware codec generates per-type behaviour from the Underlying
  instead of N hand-written codecs.

These are **anticipated** consumers, not realised ones. Form-D demand
is the validation question Carrier still has to answer empirically;
see Part 6 (deferred work) for the cross-Carrier-utilities decision.

---

## Part 2 — The protocol surface

### Declaration

```swift
public protocol Carrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}
```

Five design points are load-bearing:

1. **`~Copyable, ~Escapable` suppression on Self** — admits all four
   quadrants of conforming types. `Tagged<Tag, MoveOnlyResource>` is
   a legitimate, non-Copyable Carrier; `Buffer.Scope<Base>` is a
   legitimate, ~Escapable Carrier.

2. **`~Copyable & ~Escapable` suppression on `Underlying`** — admits
   all four quadrants of carried values. The phantom-typed wrapper
   isn't a Copyable-only abstraction; it spans the whole
   `Copyable × Escapable` square.

3. **`Domain` defaults to `Never`** — bare value types (Cardinal,
   Ordinal, etc.) conform with `Domain = Never`; Tagged conforms with
   `Domain = Tag`. The default makes trivial self-carriers ship in a
   single line.

4. **`underlying` is `borrowing get` with `@_lifetime(borrow self)`**
   — works for all four quadrants. A by-value getter would forbid
   ~Copyable Underlying (no copy); a by-value getter on ~Escapable
   self would forbid lifetime scoping. The borrow + lifetime annotation
   makes the four-quadrant matrix coherent.

5. **`init(_:)` is `consuming` with `@_lifetime(copy underlying)`** —
   transfers ownership for ~Copyable Underlying (load-bearing); is a
   no-op for Copyable. Failable constructors are deliberately not
   admitted here — see Part 4 vs RawRepresentable.

`<Underlying>` is the **primary associated type** per SE-0346, so
`some Carrier<Cardinal>` is a natural call-site spelling.

### Trivial-self defaults

Four extensions provide `underlying` and `init(_:)` for the
`Underlying == Self` case across the four quadrants:

```swift
extension Carrier where Underlying == Self {
    public var underlying: Self { _read { yield self } }
    public init(_ underlying: consuming Self) { self = underlying }
}

extension Carrier where Underlying == Self, Self: ~Copyable {
    public var underlying: Self { _read { yield self } }
    public init(_ underlying: consuming Self) { self = underlying }
}

// Mirror variants for ~Escapable and ~Copyable & ~Escapable Self.
```

The four explicit declarations exist because Swift cannot currently
flow the suppression through one default. The `_read { yield self }`
pattern (instead of `borrowing get { self }`) avoids consuming `self`
in the ~Copyable Self case — a rule confirmed empirically through the
2026-04-23 lifetime-chain investigation in `swift-ownership-primitives`.

### Filenames

Files are named by the where-clause shape rather than the `+`-suffix
extension pattern (`Carrier+Q1.swift`, etc.). The where-language form
is preferred because it is self-documenting at the file level:

```
Sources/Carrier Primitives/
├── Carrier.swift
├── Carrier where Underlying == Self.swift
├── Carrier where Underlying == Self, Self ~Copyable.swift
├── Carrier where Underlying == Self, Self ~Escapable.swift
└── Carrier where Underlying == Self, Self ~Copyable & ~Escapable.swift
```

The convention is documented for the ecosystem at large under
`code-surface` skill `[API-IMPL-007]`'s where-clause amendment.

### Stdlib-integration conformances

The `Carrier Primitives Standard Library Integration` target ships 24
conformances: `extension X: Carrier { typealias Underlying = X }`
where the trivial-self default extension provides `underlying` and
`init(_:)` for free.

```
Bool, Character, Unicode.Scalar, StaticString, String, Substring,
Int, Int8, Int16, Int32, Int64, Int128,
UInt, UInt8, UInt16, UInt32, UInt64, UInt128,
Float, Float16, Double, Duration,
Span, RawSpan, MutableSpan, MutableRawSpan,
ObjectIdentifier, Never
```

The four span types exercise the ~Escapable quadrants. `Never`
exercises the uninhabited-type edge case (verifies the protocol
typechecks against a type with no values).

15 SLI skip-rationale documents (covering ~25 stdlib types after
expanding multi-type families like `sli-range-family.md`,
`sli-unsafe-pointers.md`, and `sli-foundation.md`) document *which*
stdlib types to skip (Array, Set, Dictionary, Optional, Result, Slice,
etc.) per-type in `Research/sli-*.md`. The recurring rationale: trivial
form is zero-payoff; parametric form pre-commits a Domain/Underlying
choice that consumers should own; multi-axis generics don't fit
Carrier's single-Underlying abstraction; "no demonstrated use case"
→ skip.

---

## Part 3 — Tagged as the canonical Carrier

A natural design question: is Carrier equivalent to a hypothetical
`Tagged<A, B>.\`Protocol\``?

**Strict answer**: no. A Tagged-shaped protocol would describe "things
shaped like Tagged" (with `__unchecked:` init, phantom Tag).
**Bare Cardinal doesn't conform** — it has no `__unchecked:` init, no
phantom Tag.

**Spiritual answer**: yes. Strip away the bare-self case and the two
collapse. Carrier accepts the bare case via `Domain = Never`; that
single row is the wedge.

The relationship matches a familiar shape:

| Abstract interface | Canonical generic implementation |
|--------------------|----------------------------------|
| `Sequence` | `Array<T>` (any T → free Sequence of T) |
| Optional-like | `Optional<T>` (any T → free nullable T) |
| `Carrier` | `Tagged<Tag, V>` (any (Tag, V) → free Carrier with Domain=Tag, Underlying=V) |

**Carrier is the abstract interface that abstracts Tagged-style
wrapping; Tagged is the canonical generic implementation.**

A new value type V joins the Carrier family in two extensions, not one:

- `extension V: Carrier where Underlying == V` — V carries itself
  (trivial Carrier, Domain = Never)
- `extension Tagged: Carrier where RawValue == V, Tag: ~Copyable` —
  Tagged generates Carriers of V for any Tag

Together, V plus all its Tagged variants form a Carrier-of-V family.
APIs taking `some Carrier<V>` accept the union.

### The cascading conformance

`swift-tagged-primitives` ships:

```swift
extension Tagged: Carrier where RawValue: Carrier {
    public typealias Domain = RawValue.Domain
    public typealias Underlying = RawValue.Underlying
    public var underlying: RawValue.Underlying { rawValue.underlying }
    public init(_ underlying: consuming RawValue.Underlying) {
        self.init(__unchecked: (), RawValue(underlying))
    }
}
```

This single extension lifts ~80 ecosystem typealias sites into the
Carrier family automatically. No per-type-per-Tag conformance is
required.

The cascade also handles **nested Tagged**. `Tagged<Outer, Tagged<Inner,
Cardinal>>` is a Carrier with `Underlying == Cardinal` because the
recursive cascade unwraps both layers.

### What Tagged is to Carrier — two readings

| As a... | What it is |
|---------|------------|
| Concrete struct | A 2-param phantom-typed wrapper |
| Generic constructor | The function `(Tag, V) → Carrier<V>` |

The second reading is what makes Tagged the universal Carrier-builder.
**Anywhere you want a Carrier with a specific Domain, you reach for
Tagged**. You don't author a custom Carrier conformance for a new
phantom Tag; you instantiate `Tagged<User, MyValue>` and the
conformance is parametric.

Bare types (Cardinal, Ordinal) conform separately as trivial Carriers
because they don't need a phantom.

The cascade also generalizes beyond Tagged-as-storage: a future
heap-allocated wrapper, a SmallVec-style storage — anything with a
(phantom domain, underlying value) pair could conform. **Carrier
commits to the projection, not to Tagged's storage**.

---

## Part 4 — Why Carrier and not RawRepresentable

The most natural question on first reading: doesn't `RawRepresentable`
already do this? The full answer is in the dimensional analysis below;
the short answer is no, and they are **non-substitutable** by design.

### The shapes side-by-side

```swift
public protocol RawRepresentable {
    associatedtype RawValue
    init?(rawValue: Self.RawValue)
    var rawValue: Self.RawValue { get }
}

public protocol Carrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain:     ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable
    var underlying: Underlying { @_lifetime(borrow self) borrowing get }
    @_lifetime(copy underlying) init(_ underlying: consuming Underlying)
}
```

Superficial similarity stops at the surface. Below is where it diverges
across nine dimensions.

### The nine dimensions

| Dimension | RawRepresentable | Carrier |
|-----------|------------------|---------|
| Init fallibility | Yes (`init?`) | No |
| ~Copyable / ~Escapable support | No | Yes (fundamental) |
| Ownership annotations | None | `consuming` init, `borrowing get`, `@_lifetime` |
| Associated type count | 1 (RawValue) | 2 (Domain, Underlying) |
| Primary associated type | No | Yes (Underlying) |
| Stdlib-integrated features | Codable, OptionSet, enum rawValue | None |
| Foundation era | Pre-ownership | Post-ownership |
| Round-trip shape | Failable, validating | Total for Copyable, weakened-but-total for ~Copyable |
| Cross-type generic algorithms | Not expressible | Fully expressible (Form D) |
| Init label convention | Labeled (`rawValue:`) | Unlabeled |

The two largest divergences:

**Init fallibility**: RawRepresentable's `init?(rawValue:)` is
load-bearing for enum-from-Int and OptionSet-bitmask use cases. Carrier
is never-failing because `Tagged<User, UInt64>(42)` cannot fail —
any UInt64 is a valid underlying for the phantom-typed wrapper. A
non-failing init can't satisfy `init?(rawValue:)` without always
returning `.some` (cosmetic fallibility); going the other direction
forces every Carrier conformer to pretend construction can fail (false
for canonical conformers).

**Quadrant coverage**: RawRepresentable was authored before Swift had
ownership language features. Every stdlib facility that treats
RawRepresentable specially (Codable auto-synthesis, Hashable
derivation) assumes Copyable RawValue. Retrofitting RawRepresentable
to admit ~Copyable is an ABI break across the stdlib. Carrier admits
all four quadrants on both sides because that's why it exists.

### The decision

1. **Carrier does not refine RawRepresentable** — the init-fallibility
   mismatch, the quadrant coverage, and the dual-associated-type
   cardinality are each structurally incompatible.

2. **Ecosystem types should NOT dual-conform.** If a type is
   phantom-typed-wrapper-shaped, conform to Carrier. If a type is
   validating-raw-value-shaped (enum, OptionSet, validated wrapper),
   conform to RawRepresentable. Do not conform to both — the init
   semantics conflict.

3. **The Tagged-doesn't-conform-to-RawRepresentable convention**
   (per `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md`
   §3.1) extends to every Carrier conformer. Cardinal, Ordinal,
   Hash.Value, Tagged all stay non-RawRepresentable; they conform to
   Carrier.

4. **API surfaces wanting "wrapper over X" should take `some
   Carrier<X>`**, not `some RawRepresentable where RawValue == X`.
   The latter excludes ~Copyable wrappers, fails for failable-init
   cases that aren't relevant, and loses Domain discrimination.

5. **RawRepresentable remains correct for its own use cases.**
   Validating enums, OptionSet conformers, Foundation-integrated types
   — all stay RawRepresentable. Carrier displaces RawRepresentable
   only for the carrier family.

### Why a type can be both — and shouldn't

Technically nothing prevents conforming to both. But:

- RawRepresentable's `init?(rawValue:)` must always return `.some` for
  Carrier's non-failing semantics to match — defeats the point of
  RawRepresentable's failability.
- Two accessors (`rawValue` and `underlying`) returning the same value
  doubles surface area.
- Consumers reading a double-conforming type are left guessing which
  protocol to target.

Pick one, based on whether the type is a carrier (Carrier) or a
raw-representable validating wrapper (RawRepresentable).

---

## Part 5 — Four-quadrant coverage operationalized

The four-quadrant claim is the load-bearing differentiator vs
RawRepresentable. Here is the operational proof: a single witness-style
generic signature that spans all four `Copyable × Escapable` quadrants
of `Underlying`.

```swift
// Borrow the Carrier, borrow its Underlying, return by value.
// Suppresses Copyable + Escapable on both Self and the return R, so the
// signature accepts every point in the Copyable × Escapable square.
func project<C: Carrier & ~Copyable & ~Escapable, R: ~Copyable>(
    _ carrier: borrowing C,
    through sink: (borrowing C.Underlying) -> R
) -> R {
    sink(carrier.underlying)
}
```

Four call sites, one signature:

```swift
// Q1 — Copyable & Escapable Underlying (the ordinary case):
let userID = User.ID(42)
let next = project(userID) { u in u &+ 1 }

// Q2 — ~Copyable & Escapable Underlying (resource wrappers):
let fileHandle = File.Handle(File.Descriptor(raw: 3))
let rawFd = project(fileHandle) { descriptor in descriptor.raw }

// Q3 — Copyable & ~Escapable Underlying (span-like views):
let bufferView: Buffer.View<UInt8> = .init(bytes[...])
let count = project(bufferView) { span in span.count }

// Q4 — ~Copyable & ~Escapable Underlying (scoped references):
let bufferScope: Buffer.Scope<Base> = ...
let snapshot = project(bufferScope) { ref in ref.summary() }
```

The conformances follow the `Nest.Name` discipline — `User.ID` (a real
`User` domain plus a nested identifier wrapper for Q1), `File.Handle`
over `File.Descriptor` (siblings in `File` for Q2), `Buffer.View` /
`Buffer.Scope` (siblings under `Buffer` for Q3 and Q4). None compound;
each sits under a namespace with other inhabitants.

### Why RawRepresentable cannot host this

```swift
// Does not compile for ~Copyable Underlying; cannot be satisfied for ~Escapable:
func project<C: RawRepresentable, R>(
    _ carrier: C,
    through sink: (C.RawValue) -> R
) -> R {
    sink(carrier.rawValue)
}
```

Categorically excludes Q2, Q3, Q4. A pre-Carrier ecosystem solving the
same problem would need:

- Four distinct overloads, one per quadrant, tied together by name only.
- Four sibling protocols plus a manual dispatch layer at every use site.
- Existentials with type erasure that discards quadrant information.

Carrier collapses all of that to one signature. **That is the
four-quadrant coverage claim, operational.**

The first real consumer will appear in a downstream package — a
serialization witness, a diagnostic-emission witness, a hash-projection
witness — each with `project`-shaped signature and domain-specific
sink semantics.

---

## Part 6 — Pattern relationships

Carrier sits in a small family of related ecosystem patterns. Three
distinct, COMPOSABLE patterns are visible:

| Pattern | What it adds | Examples |
|---------|--------------|----------|
| **Per-type capability protocol with Tagged forwarding** | `V.\`Protocol\`` lets APIs accept bare V + Tagged<_, V> | Cardinal, Ordinal, Hash, Affine.Discrete.Vector |
| **Carrier super-protocol** (parameterized) | Cross-V generic algorithms; uniform reflection | Carrier<Underlying> (this package) |
| **Self-projection default** | A protocol's associatedtype defaults to `N<Self>` | Borrow / Mutate (per `swift-ownership-primitives/Research/self-projection-default-pattern.md`) |

The patterns are **not redundant** with each other; they address
different problems. The self-projection pattern's Borrow case has no
"Underlying" concept — Borrow IS the projection, not a carrier of one.
Conversely, Cardinal has no `N<Self>` projection — it carries a value,
it doesn't project Self.

### The role-class taxonomy: who joins Carrier and who stays sibling

Five role-classes have surfaced through the carrier-ecosystem migration
(Phases 1–3 + 5 of the `swift-institute/Research/carrier-ecosystem-application-inventory.md`):

| Role-class | Examples | Carrier-compatible? |
|-----------|----------|---------------------|
| **Value-carrying with Self+Self operators** | Cardinal, Hash.Value, Affine.Discrete.Vector | ✓ migrate to Carrier — per-type protocol redundant |
| **Operator-ergonomics with Self+Self.Count operators** | Ordinal | ✗ stay sibling — Carrier has no `Self.Count` machinery |
| **Witness protocols** ("I produce X") | Comparison, Equation | ✗ stay sibling — different role from value-carrying |
| **Domain-specific value types** with no phantom-tagged variants | Decimal.Exponent, Time refinement types, RFC magnitudes | ✗ stay distinct — no phantom Domain story |
| **Validating wrappers** (failable init) | enum-with-RawValue, OptionSet | RawRepresentable, not Carrier |

**The decision rule**: examine the operators on the per-type protocol's
extension. If they are `Self + Self → Self` shape, migrate to
Carrier-where-Underlying-X — the per-type protocol becomes redundant.
If they are `Self + Self.Count → Self` shape with `Count` as an
associated type, retain as sibling.

### Why Ordinal stays sibling, not refinement

Carrier has no associated type beyond `Domain` and `Underlying`.
Ordinal.\`Protocol\` carries a per-conformer `associatedtype Count:
Carrier<Cardinal>` that drives `static func + (Self, Self.Count) ->
Self`. Without the Count machinery, `slot + .one` ceases to infer at
call sites — across O(N) sites in the consumer ecosystem.

The right shape: Ordinal conforms to BOTH protocols independently as
siblings:

- `Ordinal: Carrier` (cross-type generic dispatch via Form-D)
- `Ordinal: Ordinal.\`Protocol\`` (operator-ergonomics with Count)

`Tagged<Tag, Ordinal>: Carrier` (via the parametric Tagged extension);
`Tagged<Tag, Ordinal>: Ordinal.\`Protocol\`` (via a separate conditional
extension). Refinement would force the protocol-extension cost
(Tagged conformance authored twice) without compensating benefit.

Cardinal had no such complication and migrated to Carrier-where-Underlying-Cardinal
without retaining its per-type protocol.

### Why Decimal.Exponent stays distinct, not Carrier

Phase 4 of the carrier-ecosystem migration was Decimal Tagged refactor
— migrate `Decimal.Exponent`, `Decimal.Precision`, `Decimal.Payload`
into Tagged-over-Int. The work was CANCELLED on four-way convergence
(`swift-institute/Research/decimal-carrier-integration.md`):

1. **Naming obstacle**: a Tagged refactor would require synthesizing
   `*Tag` phantom types (`ExponentTag`, `PayloadTag`) because the value
   types ARE the namespace name — convention break per the no-`*Tag`
   suffix rule.
2. **Literal-conformance gating**: `Decimal.Exponent` has
   `ExpressibleByIntegerLiteral`, which Tagged doesn't transparently
   forward.
3. **`[IMPL-001]` domain-erasure**: treating Decimal arithmetic as
   generic Int arithmetic would erase the domain semantics (power-of-10
   exponent vs significant-digit count vs NaN diagnostic payload —
   distinct semantic types).
4. **`[RES-018]` second-consumer hurdle**: no concrete consumer of
   "Decimal.Exponent as a Carrier" exists.

The diagnostic test for the role-class: would treating the type's
arithmetic as generic `Carrier<Underlying>` arithmetic violate the
type's domain semantics? If yes, retain as standalone domain type.
RFC-spec'd magnitude types and refinement types with `init throws`
validation fall in this class too.

---

## Part 7 — Round-trip semantics for ~Copyable Underlying

The Carrier shape — `borrowing get` for `underlying`, `consuming init`
— invites a confused reading: "given a Carrier, you can read its
underlying and reconstruct an equivalent Carrier from what you read."

For **Copyable** Underlying that is correct. For **~Copyable**
Underlying it is **structurally impossible**.

### The semantic property

The getter yields a borrow of Underlying. The init consumes an OWNED
Underlying. A borrow is not owned; you cannot pass a borrow where a
consume is expected. For Copyable Underlying this asymmetry is
invisible because any borrow can be copied. For ~Copyable Underlying
there is no copy.

```swift
// COMPILE ERROR for File.Handle with ~Copyable File.Descriptor:
let first: File.Handle = ...
let second = File.Handle(first.underlying)    // ✗ can't consume a borrow
```

`first.underlying` is a borrowed `File.Descriptor`. `File.Handle.init(_:)`
takes `consuming File.Descriptor`. The call cannot typecheck.

### What works and what doesn't

| Scenario | Copyable Underlying | ~Copyable Underlying |
|----------|---------------------|----------------------|
| Borrow `underlying`, inspect, build new carrier from a copy | ✓ works (copy implicit) | ✗ cannot compile |
| Consume the carrier to extract owned `underlying`, pass to new `Carrier.init(_:)` | ✓ works (destroys original) | ✓ works (and destroys original) |
| Own a *separate* `Underlying`, pass to `Carrier.init(_:)` | ✓ works | ✓ works |
| Round-trip `self.underlying → Self.init(self.underlying)` with `self` still valid | ✓ works | ✗ impossible by design |

### Why this is not a bug

- **Linear-type discipline**: ~Copyable types are linear. A round-trip
  that preserves the original is a Copyable property, not a universal
  Carrier property.
- **Ownership transfer**: `consuming init` is correct. An alternative
  `init(borrowing:)` would require copying the borrowed value,
  forbidden for ~Copyable.
- **`_read { yield self }`**: the trivial-self default uses `_read`
  precisely because `borrowing get { self }` would consume `self` for
  ~Copyable Self.

### The correct ~Copyable patterns

**Option A — Consume and reconstruct**:

```swift
var handle: File.Handle = ...
let descriptor = consume handle               // destroys handle; takes ownership
// ... do something with descriptor, perhaps producing a new owned value ...
let rebuilt = File.Handle(descriptor)         // consumes descriptor; produces new carrier
```

**Option B — Supply a fresh Underlying**:

```swift
let freshDescriptor = File.Descriptor(raw: openedByCaller)
let handle = File.Handle(freshDescriptor)
```

Generic algorithms over `some Carrier<Underlying>` that need to
"rebuild" a carrier face a three-way choice:

1. **Constrain `where Underlying: Copyable`** — rebuild via copy is
   cheap and clean.
2. **Take `consuming Carrier`** — algorithm owns the carrier and can
   extract via consume.
3. **Stay read-only** — observe via borrow, return a fresh value
   without rebuilding any carrier. **Most algorithms fall here.**

The round-trip asymmetry only matters for algorithms that *transform*
a Carrier; for those, either a Copyable constraint or a consuming
signature is required.

---

## Part 8 — Read-only by design

Three deliberate stances on extending Carrier's API surface:

### No `Carrier.Mutable` refinement at v0.1.x

`Carrier`'s `var underlying: Underlying` requires only `borrowing get`
— read-only projection. Mutation is per-conformer concrete API; the
canonical generic mutation channel is `init(_:)` reconstruction
(consume the carrier, take ownership of the underlying, mutate it
externally, rebuild via `init(_ underlying:)`).

**Why read-only is the right default**:

1. **Phantom-typed identity guarantee.** Most Carrier conformers are
   wrappers — User.ID, Order.ID, Cardinal, Ordinal. The wrapper's
   purpose is to keep its underlying value distinct at the type level.
   Mutation through `.underlying` would let consumers mutate the raw
   value in place without going through `init(_:)`, eroding the
   construct-via-the-type's-API boundary.

2. **RawRepresentable precedent.** Stdlib's `RawRepresentable.rawValue`
   is `get`-only. The explicit-projection stance is shared.

3. **Mutation channel is `init(_:)`.** Reconstruction matches the
   ownership semantics of ~Copyable carried types.

**Why `Carrier.Mutable` (the dotted form) is structurally awkward**:

Swift doesn't allow nesting protocols inside protocols. The dotted
form requires a namespace refactor — converting `Carrier` from a
top-level protocol to an enum namespace + `Carrier.\`Protocol\``.
That convention works for *noun-types* (Cardinal is both a value type
AND a namespace via the back-tick trick). Carrier has no concrete
`Carrier` value; forcing it into a namespace shell creates a
pure-namespace enum just to nest `Mutable` underneath. Asymmetric with
Tagged (a real concrete generic type).

**Three honest options** when mutation demand surfaces:

| Option | Shape | Cost |
|---|---|---|
| (A) Don't add it | Mutation is per-conformer concrete API | Zero |
| (B) Top-level `MutableCarrier` (compound name; cf. `MutableCollection`) | `[API-NAME-001]` exempts capability-variant compound names | One protocol |
| (C) Separate `swift-mutable-primitives` package with `Mutatable` protocol | Orthogonal to Carrier; types conform to both | New package; cleanest factoring |

A focused Tier-2 investigation of (C) — `swift-mutator-primitives` —
**completed DEFERRED** in 2026-04-25. Findings:

- The compositional machinery is already shipped at the ecosystem
  layer: `swift-optic-primitives` (Lens/Prism/Iso/Affine/Traversal
  with composition + laws) and `swift-algebra-*`
  (Magma/Monoid/Group/Ring/Field/Module witnesses).
- The two well-shaped gaps are small extensions to existing
  primitives, not a new package: `Optic.Setter` for write-only
  mutation; `Algebra.Semilattice` for CRDT-merge.
- The genuine academic gap (handlers for linear/borrowed state with
  a lifetime-bounded witness) lacks a credible second consumer
  per [RES-018].

Empirical Swift findings, reusable across the ecosystem:

- `mutating _modify` is NOT a valid protocol property requirement
  (Swift accepts only `get`/`set` in property requirements).
- `@_lifetime(&self)` (NOT `@_lifetime(borrow self)`) on `_modify`
  for ~Escapable Self.
- `WritableKeyPath<Root, Value>` carries an implicit
  `Root: Copyable & Escapable` constraint that propagates through
  protocol-extension dynamic-member subscripts — same Q1-only
  constraint as for read-only KeyPath.

The deferral remains in force. Revisit triggers:

- A concrete consumer with a genuine need for `func f<C: ???>(_ c:
  inout C) { c.underlying.foo = bar }` generic dispatch.
- Swift's KeyPath / dynamic member lookup story evolves enough that
  WritableKeyPath-based dynamic mutation forwarding becomes viable
  (currently blocked by Q1-only constraint).

### No `@dynamicMemberLookup` — asymmetric across quadrants

```swift
@dynamicMemberLookup    // ❌ rejected
public protocol Carrier<Underlying>: ~Copyable, ~Escapable { ... }

extension Carrier {
    public subscript<T>(dynamicMember keyPath: KeyPath<Underlying, T>) -> T {
        underlying[keyPath: keyPath]
    }
}
```

The KeyPath subscript materializes only when `Self: Copyable & Escapable`
AND `Self.Underlying: Copyable & Escapable` — Q1-only.

| Quadrant | Self | Underlying | Verdict |
|----------|------|------------|---------|
| Q1 | Copyable & Escapable | Copyable & Escapable | CONFIRMED — resolves through dynamic lookup |
| Q2 | ~Copyable | ~Copyable | REFUTED — `requires that Self conform to Copyable` |
| Q3 | ~Escapable | ~Escapable | REFUTED — `requires that Self conform to Escapable` |
| Q4 | ~Copyable & ~Escapable | ~Copyable & ~Escapable | REFUTED by transitivity |

If we add `@dynamicMemberLookup`:

1. **Q1 conformers get the ergonomic** — both trivial self-carriers
   (Int, String) and Tagged carriers with Copyable Underlying gain
   dot-syntax member access.
2. **Q2/Q3/Q4 conformers silently do not** — a consumer reaching for
   `someUniqueCarrier.raw` gets the protocol's Copyable/Escapable
   diagnostic, not the affordance they expected. The error mentions
   constraints they did not write.
3. **Generic algorithms `func f<C: Carrier>(_ c: C)`** cannot rely on
   dot-syntax in any case — dynamic member lookup is a concrete-type-
   only affordance.

### Conceptual fit

Carrier exists to keep phantom-typed wrappers distinct from their
underlying — `User.ID` is not an `Int`. Dynamic member lookup forwards
member access from the wrapper to the underlying, partly undoing that
distinction. The wrapper's API surface becomes "everything Underlying
exposes plus what the wrapper itself adds," which is exactly what the
type-system separation was preventing.

This inherits the `RawRepresentable.rawValue` projection-is-explicit
stance: `wrapper.underlying.foo` is intentionally heavier than
`wrapper.foo` because the dot signals "I am crossing from the
carrier's domain into the underlying's."

### Reversibility

| Action | Reversibility |
|--------|---------------|
| Add `@dynamicMemberLookup` to Carrier later | Non-breaking |
| Remove `@dynamicMemberLookup` from Carrier later | Breaking |

One-way door. Conservative default.

### Consumer-side escape hatch

A consumer who specifically wants dynamic member lookup for their own
Carrier-conforming Q1 type can apply the annotation locally:

```swift
extension User {
    @dynamicMemberLookup
    struct ID: Carrier {
        typealias Underlying = User
        var user: User
        var underlying: User { user }
        init(_ underlying: consuming User) { self.user = underlying }

        subscript<T>(dynamicMember keyPath: KeyPath<User, T>) -> T {
            user[keyPath: keyPath]
        }
    }
}
```

Scopes the choice locally without imposing it on all Carrier conformers.

### No cross-Carrier utilities at v0.1.x

A Tier-2 investigation surveyed seven candidate utilities against
prior art (Haskell `tagged`/`lens`, Rust `derive_more`/PhantomData,
Scala 3 opaque types, F# units of measure, OCaml private types,
Idris/Agda) and the academic literature (Reynolds parametricity,
Wadler free theorems, Breitner et al. Coercible).

| # | Utility | Prior art | Carrier-feasible | Second consumer? | Verdict |
|---|---------|-----------|------------------|------------------|---------|
| 1 | `describe` | Universal | YES (Q1+) | NONE | DEFER |
| 2 | `reroot` | Haskell `retag` | NO (Q1-only via copy; Q2/Q3/Q4 blocked by borrow-vs-consume) | NONE | DEFER |
| 3 | `equate` | Partial | YES (Q1) | NONE | DEFER (semantically suspect) |
| 4 | `project` | Lens-style witness | YES (all four quadrants) | NONE (sketch only) | DEFER (sketch is the spec) |
| 5 | `Carrier: Equatable` | Haskell `deriving newtype Eq` | Q1-only conditional | NONE | DEFER (4 concerns) |
| 6 | `Carrier: Hashable` | Haskell `deriving newtype Hashable` | Q1-only conditional | NONE | DEFER (4 concerns) |
| 7 | `Carrier: CustomStringConvertible` | Haskell `Show` | Q1-only conditional | NONE | DEFER (4 concerns) |

Zero of seven candidates have a credible second consumer in the
ecosystem as of 2026-04-26.

**Cross-language observation**: only ecosystems with **language-level
support for zero-cost coercion** (Haskell Coercible, Idris/Agda
dependent types) ship `retag`-style cross-tag morphisms. Ecosystems
that lack such language support (Rust, Scala 3 opaque types, F#
units of measure, OCaml private types) **do NOT ship cross-tag
morphisms** — they require explicit per-pair conversions instead.
F# units of measure are the cleanest example of a phantom-typed
system that ships ZERO cross-phantom utilities by design.

Swift is in the "lacks language-level support" group. The
cross-language consensus suggests cross-Carrier utilities at the
language-untyped layer go *against* prior art; the burden of proof
sits on the demand-evidence side.

**The decision** ([RES-018] hurdle, plus four compounding concerns
on conditional stdlib conformances):

1. **No utility ships at v0.1.x.** The structural decision (utilities
   inside Carrier Primitives; methods on Carrier protocol via
   constraint extensions; file naming `Carrier where {clause}.swift`)
   is recorded for when a real consumer surfaces.
2. **The candidate list is recorded** as anticipated future ship-list
   per `[RES-006a]`, with prior-art citations.
3. **The `reroot` blocker is documented as a structural protocol
   gap**: `borrow → consume` is impossible for ~Copyable Underlying
   without adding a new Carrier protocol method (e.g., `consuming
   func unwrap() -> Underlying`). That is a separate Tier-2
   investigation gated on `reroot` demand.
4. **`project` is the strongest near-term ship candidate** — already
   has a Tier-1 REFERENCE sketch, validates all four quadrants
   (the Carrier design payoff), has anticipated consumers documented.
   Promote when first concrete consumer surfaces.

### Acceptance gate (when shipping any utility)

For ANY future utility to graduate from candidate-list to shipped:

1. **Concrete second consumer named** — the consumer's signature
   demonstrates material benefit from the utility being on Carrier
   (vs. inline at the use site).
2. **Quadrant story explicit** — which of Q1/Q2/Q3/Q4 the utility
   supports, with rationale for any quadrant excluded.
3. **Conformance-shadowing analysis** — does the utility introduce
   ambiguity with conformer-side per-type implementations? Empirical
   verification before shipping.
4. **Verification spike per [EXP-006b]** if the utility involves
   conditional protocol conformance.

---

## Part 9 — Theoretical foundations

The Carrier pattern recurs in academic literature under several guises.
Six lenses, each grounded in a verified primary source, illuminate
different aspects.

### Phantom types (Leijen & Meijer 1999; Hinze 2003)

A phantom type is a type parameter that does not appear in any data
constructor — it constrains type-level reasoning without runtime cost.
`Tag` in `Tagged<Tag, V>` is exactly this. `Domain` in Carrier carries
the phantom information at the protocol level.

### First-class phantom types (Cheney & Hinze 2003)

Type-equality witnesses (`TypeEq a b`) and phantom indexing simulate
dependent types. Relevant operations are equality witnesses, not
utilities on the wrappers themselves — supports the decision against
ad-hoc cross-Carrier morphisms.

### Type classes & ad-hoc polymorphism (Wadler & Blott 1989)

Carrier IS a type class in Wadler's sense: a name, an interface,
implementations per type. The ecosystem ships parametric Tagged
conformance and bare-self conformances; the type class admits any
new conformer without prior knowledge of it.

### Polymorphism taxonomy (Cardelli & Wegner 1985)

Carrier sits at the intersection of:

- **Parametric polymorphism** — `Carrier<Underlying>` is parametric
  in Underlying.
- **Subtype polymorphism** — `some Carrier<Cardinal>` accepts every
  conformer.
- **Inclusion polymorphism (constrained)** — `where Underlying ==
  Cardinal` narrows the family.

It deliberately does NOT support **coercion polymorphism** — the
RawRepresentable-style implicit conversion. Phantom-typed-wrapper
discipline forbids it.

### Parametricity & free theorems (Reynolds 1983; Wadler 1989)

For any function `f : ∀ Tag. Tagged<Tag, V> → Tagged<Tag, V>`
polymorphic in `Tag`, parametricity guarantees `f` must preserve the
tag. This is the formal guarantee that phantom tags are tamper-proof.
It also bounds the candidate utility set: cross-Tag operations
(`reroot`) require *explicit* construction of the target carrier; they
are not implicit consequences of parametricity.

### Coercibility (Breitner et al. 2014, ICFP)

Haskell's `Coercible` / role system makes `retag :: Tagged s b ->
Tagged t b` provably zero-cost. Swift has no equivalent. The cost of
a Swift `reroot` would be a typed function call, not a representational
no-op. The cross-language survey shows that ecosystems lacking
Coercible-style language support (Rust, Scala, F#, OCaml) do not ship
cross-tag morphisms; the academic foundation is that without
Coercible, cross-tag operations are not the correct abstraction layer
for the host language.

### Higher-kinded encoding (Yallop & White 2014)

`Carrier<Underlying>` parameterized over `Underlying` is a
higher-kinded encoding of "the family of types that carry an
Underlying". Swift's SE-0346 primary-associated-type spelling realises
this at the protocol level — `some Carrier<Cardinal>` reads as the
first-order constraint while preserving the higher-kinded structure
in the language semantics.

### Connection to Tagless Final (Carette, Kiselyov, Shan)

Tagless Final encoding represents DSLs as sets of typeclass methods
parameterized over the result type. `Carrier`'s Form-D shape — `func
describe<C: Carrier>(_ c: C) -> String` — has the same structure: the
algorithm is parameterized over the carrier kind, dispatched to per-
conformer behaviour. The pattern Carrier enables is not novel; it
realizes a known categorical construction in Swift's type system.

For the full prior-art treatment, see the cross-package Tier-3 study
`swift-institute/Research/phantom-typed-value-wrappers-literature-study.md`
(36 papers, 5-language comparative analysis).

---

## Part 10 — Open questions and revisit triggers

The vision is committed; specific extensions remain conditionally
deferred. Each has explicit revisit triggers.

### Form-D demand validation

Form-D is the design payoff. As of 2026-04-26 (post-Phase-3 of the
carrier-ecosystem migration), no production cross-Carrier algorithm
exists. The carrier-integration retrospective explicitly flags this
as the unresolved validation question.

**Revisit trigger**: a downstream package authors a `func f<C:
Carrier>(_ c: C)` algorithm against Carrier. At that point: promote
`project` to a shipped utility; consider `describe` and `equate`
on case-by-case basis.

### Cross-Carrier utilities ship-list

Each candidate has documented prior art but lacks a second consumer.
**Revisit trigger**: the [RES-018] second-consumer hurdle is met
for any specific utility. Acceptance gate (Part 8 above) applies.

### `reroot` for ~Copyable Underlying

Structurally blocked: `borrow → consume` is impossible without a new
Carrier protocol method. **Revisit trigger**: a real consumer
surfaces with a Q1-acceptable use case OR the ecosystem decides to
widen Carrier's protocol surface with consume-extraction.

The widening investigation MUST address: (a) does the trivial-self
default still work for Q3 ~Escapable Self under a new consume
requirement? (b) what's the ABI commitment of widening the protocol
surface mid-cycle? (c) does the addition trigger the
~Copyable-round-trip concern?

### `Carrier.Mutable` / mutation generic dispatch

The `swift-mutator-primitives` investigation completed DEFERRED.
**Revisit triggers**:

- A concrete consumer surfaces a genuine need for `func f<C: ???>(_
  c: inout C) { c.underlying.foo = bar }` generic dispatch.
- Swift's KeyPath / dynamic member lookup story evolves enough that
  `WritableKeyPath`-based dynamic mutation forwarding becomes viable
  (currently blocked by Q1-only Copyable & Escapable constraint).

If shipping happens, the principled shape is **option (C)**: a
separate `swift-mutable-primitives` package with a `Mutatable<Value>`
protocol orthogonal to Carrier; types that need both conform to both.

### `@dynamicMemberLookup` for Q1

Asymmetric quadrant ergonomics is the rejection criterion.
**Revisit triggers**:

- Swift relaxes `KeyPath`'s `Root: Copyable & Escapable` constraint
  such that `KeyPath<~Copyable Root, T>` and `KeyPath<~Escapable Root,
  T>` typecheck.
- A pattern emerges where multiple ecosystem packages all apply
  `@dynamicMemberLookup` to their Q1 Carrier conformers — the
  consumer-side escape hatch becomes repetitive boilerplate.

Neither trigger is active as of 2026-04-29.

### Stdlib protocol auto-derivation (`Equatable`, `Hashable`,
`CustomStringConvertible`)

Each carries the standard [RES-018] hurdle PLUS an asymmetric-quadrant-
ergonomic concern PLUS a design-intent reversal concern (Carrier was
designed for ZERO stdlib-level benefit) PLUS an ecosystem-wide
blast-radius concern (a single `Carrier: Equatable` extension cascades
through every conforming type).

**Revisit trigger**: a Carrier-aware generic consumer surfaces and
each of the four concerns can be addressed with evidence.

---

## Quick reference

### When to use what

| If you're... | Use |
|--------------|-----|
| Writing an API for `Cardinal` quantities | `func f(_ c: some Carrier<Cardinal>) -> Cardinal` |
| Writing an API for `Ordinal` positions | `func f<O: Ordinal.\`Protocol\`>(_ o: O) -> O` (Ordinal stays sibling per role-class taxonomy) |
| Writing an API that should accept ANY Carrier | `func describe<C: Carrier>(_ c: C) -> String` |
| Adding a new Tag for an existing value type V | `typealias MyCount = Tagged<User, V>` — Carrier conformance comes free via the Tagged cascade |
| Adding a new value type V to the Carrier family | Two extensions: `extension V: Carrier where Underlying == V` AND `extension Tagged: Carrier where RawValue == V, Tag: ~Copyable` |
| Adding a `~Copyable` value type | Can conform to Carrier via the Q2 default; round-trip semantics weaker — use consume-and-reconstruct |
| Want cross-Carrier utility (reroot, describe, etc.) | Inline at use site for now; open an issue when N≥2 consumers exist |
| Considering `@dynamicMemberLookup` | Apply locally to your Q1 Carrier-conforming type, not to Carrier itself |
| Considering generic mutation | Use `init(_:)` reconstruction; concrete-type API for in-place mutation; `Mutatable` protocol deferred |
| Existential `any Carrier<X>` | Type-checks but loses Underlying; prefer `some Carrier<X>` for generic dispatch |

### Decision matrix

| Decision | Status | Rationale |
|----------|:------:|-----------|
| Carrier ships at v0.1.0 (Option B parameterized) | ✓ | Strictly more flexible than refinement; clean call-site spelling |
| `Carrier` does NOT refine `RawRepresentable` | ✓ DECISION | Init fallibility, ~Copyable support, primary associated type all incompatible |
| Tagged is the canonical generic Carrier implementation | ✓ DECISION | The cascade lifts ~80 ecosystem typealiases |
| Bare value types conform via `Domain = Never` | ✓ DECISION | Trivial self-carrier; value type plus `typealias Underlying = Self` is one line |
| Per-type protocols (Cardinal, Ordinal, Hash) stay siblings | ✓ DECISION | Refinement triggers double-Tagged-conformance cost |
| Operator-ergonomics protocols (Ordinal) stay sibling | ✓ DECISION | Carrier has no `Self.Count` machinery |
| Witness protocols (Comparison, Equation) stay distinct | ✓ DECISION | Different role from value-carrying |
| Domain-specific value types (Decimal.Exponent etc.) stay distinct | ✓ DECISION | No phantom-tagged variants; cross-type generic dispatch not a use case |
| `@dynamicMemberLookup` rejected | ✓ DECISION | Asymmetric across quadrants (Q1 only) |
| `Carrier.Mutable` deferred indefinitely | ✓ DECISION | Mutation is per-conformer; generic dispatch via `init(_:)` reconstruction |
| Cross-Carrier utilities (describe, reroot, equate, project, ...) deferred | ✓ DECISION | Zero candidates pass [RES-018] second-consumer hurdle |
| Read-only `borrowing get` on `underlying` | ✓ DECISION | Phantom-typed identity guarantee; explicit-projection stance |
| `consuming` init | ✓ DECISION | Ownership transfer for ~Copyable; no-op for Copyable |
| Where-clause filename convention preferred over `+` suffix | ✓ DECISION | Self-documenting at file level; principal direction 2026-04-29 |

---

## References

### In-package experiments

- `Experiments/capability-lift-pattern/` — V0–V5 (CONFIRMED, 2026-04-22)
  — six variants of the capability-lift pattern's recipe,
  super-protocol unification options, API broadening, limits.
- `Experiments/dynamic-member-lookup-quadrants/` — V1 CONFIRMED
  (Q1 dispatch), V2/V3/Q4 REFUTED (2026-04-25) — empirical proof of
  the asymmetric-quadrant ergonomic.
- `Experiments/relax-trivial-self-default/` — quadrant coverage
  validation for the four trivial-self defaults.
- `Experiments/span-carrier-conformance/` — Q3 conformance probe
  (Span / RawSpan Carrier conformance).

### Ecosystem instances

| Type | File | Notes |
|------|------|-------|
| `Cardinal: Carrier` | `swift-cardinal-primitives/Sources/Cardinal Primitives/Cardinal+Carrier.swift` | Migrated from `Cardinal.\`Protocol\`` (Phase 2b) |
| `Ordinal: Carrier` + `Ordinal.\`Protocol\`` | `swift-ordinal-primitives/...` | Sibling, not refinement (operator-ergonomics) |
| `Affine.Discrete.Vector: Carrier` | `swift-affine-primitives/...` | Migrated from per-type protocol |
| `Tagged: Carrier where RawValue: Carrier` | `swift-tagged-primitives/Sources/.../Tagged+Carrier.swift` | The cascade — lifts ~80 typealiases |
| `Property: Carrier` (Q1+Q2) | `swift-property-primitives/Sources/.../Property+Carrier.swift` | First ~Copyable Self conformer |
| `Hash.\`Protocol\`` | `swift-hash-primitives/...` | Stays witness-style sibling |

### Cross-package research

- `swift-tagged-primitives` Research — foundational comparative
  analysis (Tagged vs point-free Tagged) where the decision that
  Tagged does not conform to RawRepresentable is recorded.
  Generalized in Part 4.
- `swift-ownership-primitives` Research — the orthogonal
  self-projection pattern (Borrow family). Cited in the pattern
  taxonomy (Part 6).
- `swift-institute` Research — ecosystem-wide artifacts: the
  carrier-ecosystem application inventory (Phase 1–3 + 5 migration
  log; "Form-D demand unrealized" finding); operator-ergonomics
  and-carrier-migration (Ordinal sibling-not-refinement); decimal-
  carrier-integration (Phase 4 cancellation); phantom-typed-value-
  wrappers-literature-study (Tier 3, 36 papers, 5-language
  comparative analysis — foundational for Part 9); the
  carrier-integration retrospective; the deferred mutator package's
  academic prior-art survey and `_modify`-across-quadrants empirical
  findings (cited in Part 8).

### Convention sources

- `[PRIM-FOUND-001]` — Foundation-free primitives layer.
- `[PKG-NAME-001/002]` — Package and namespace naming.
- `[API-NAME-001/001a]` — `Nest.Name` discipline; no compound names.
- `[API-IMPL-005/007/008]` — File structure; extension files;
  minimal type body.
- `[RES-001]`, `[RES-002a]`, `[RES-003]`, `[RES-006a]`, `[RES-018]`,
  `[RES-019]`, `[RES-020]`, `[RES-021]`, `[RES-022]` — research
  conventions.
- `[EXP-006b]` — confirmation evidence requirements for
  acceptance-gate verification spikes.
- `[IMPL-001]` — domain-erasure anti-pattern.
- `[DOC-101]` — consumer/contributor boundary in DocC.

### Language references

- **SE-0155** — `RawRepresentable` (Swift stdlib).
- **SE-0346** — Lightweight same-type requirements for primary
  associated types. Enables `some Carrier<Underlying>`.
- **SE-0309** — Unlock existentials for all protocols. Relevant to
  `any Carrier`.
- **SE-0353** — Constrained Existential Types. Enables `any
  Carrier<Cardinal>`.
- **SE-0390** — Noncopyable structs and enums.
- **SE-0427** — Noncopyable generics. Enables Q2/Q4 Carrier
  conformance.
- **SE-0506** — Noncopyable associated types. Enables Carrier's
  `~Copyable & ~Escapable` associated types.
- **Swift 6.3.1 experimental features** — `Lifetimes`,
  `SuppressedAssociatedTypes`.

### Cross-language prior art (verified 2026-04-26)

- [Hackage `tagged-0.8.10` `Data.Tagged`](https://hackage.haskell.org/package/tagged-0.8.10/docs/Data-Tagged.html)
  — `retag`, `untag`, typeclass instances forwarding via `deriving
  newtype`.
- [Hackage `lens-4.17` `Control.Lens.Wrapped`](https://hackage.haskell.org/package/lens-4.17/docs/Control-Lens-Wrapped.html)
  — `_Wrapped` Iso form.
- [Breitner, Eisenberg, Peyton Jones, Weirich, "Safe Zero-cost
  Coercions for Haskell" (ICFP 2014)](https://www.cis.upenn.edu/~sweirich/papers/coercible.pdf)
  — Coercible / role system; the language-level mechanism Swift
  lacks.
- [Rust `derive_more`](https://docs.rs/derive_more/) — newtype
  trait-forwarding; no cross-newtype morphisms.
- [Scala 3 opaque types](https://docs.scala-lang.org/scala3/reference/other-new-features/opaques.html)
  — explicit extension methods; no automatic forwarding; no
  cross-opaque-type morphism pattern.
- [F# units of measure](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure)
  — compile-time discrimination; explicit conversion factors; no
  cross-unit "rebrand" by design.
- [McBride, "Faking it: Simulating dependent types in Haskell"
  (JFP 2002)](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/faking-it-simulating-dependent-types-in-haskell/A904B84CA962F2D75578445B703F199A)
  — type-equality witnesses; phantom indexing.
- Reynolds 1983, *"Types, Abstraction, and Parametric
  Polymorphism"* — parametricity foundation.
- Wadler 1989, *"Theorems for Free!"* — free theorems for
  polymorphic functions; bounds the candidate-utility set.
- Cardelli & Wegner 1985, *"On Understanding Types, Data
  Abstraction, and Polymorphism"* — polymorphism taxonomy.
- Yallop & White 2014, *"Lightweight Higher-Kinded Polymorphism"*
  — encoding of higher-kinded structure in OCaml.
- Atkey 2009, *"Parameterised Notions of Computation"* — graded
  monad foundations.
- Carette, Kiselyov, Shan, *"Finally Tagless, Partially Evaluated"*
  — tagless final encoding.

---

## Document provenance

This vision consolidates the package's 0.1.0 design rationale into a
single coherent narrative. It absorbs prior topic-specific research
across the capability-lift pattern's recipe and super-protocol options,
the comparative analysis against `RawRepresentable`, the operational
proof of four-quadrant coverage, the design decisions on
`@dynamicMemberLookup` and mutation, the round-trip semantics for
~Copyable Underlying, the cross-Carrier-utilities ship-list survey,
and the academic-foundations grounding.

An earlier "DEFER Carrier introduction" position was empirically
superseded when Carrier shipped on 2026-04-24 and the cascading
Tagged conformance demonstrated the structural composition required.
That position's correct concerns are folded into Part 6's role-class
taxonomy.

The cross-language prior art and academic foundations are summarized
here in Part 9; the full treatment lives in
`swift-institute/Research/phantom-typed-value-wrappers-literature-study.md`
(Tier 3, 36 papers, 5-language comparative analysis).
