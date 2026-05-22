# Affine Vector Representation — Tagged vs Carrier

<!--
---
version: 1.0.0
last_updated: 2026-05-22
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

Principal direction 2026-05-22 reverted commit `8e01ee3` ("Extract Affine
Carrier + Ordinal + Tagged sub-targets to sibling packages") with the
assessment that the extraction "doesn't make sense" alongside the
suspicion that "the tagged approach is vestigial" in Affine's design.
The revert (`4a909e8`) put the Affine Carrier + Ordinal + Tagged
sub-namespace targets back inside `swift-affine-primitives`.

The handoff (`swift-institute/Audits/HANDOFF-research-tagged-vs-carrier.md`)
asks the load-bearing follow-up: **should `Affine.Discrete.Vector` be
represented as Tagged-based or Carrier-based?**

This research grounds the question in the current source (2026-05-22),
cites the prior decisions that already framed the answer, and surfaces
the structurally-correct disposition before any future Affine
modularization touches the Vector representation.

### Trigger

[RES-001] Architecture choice — design question surfaced from a
package-extraction reversal. Cannot be made without systematic analysis
of which protocol relationship is right for `Affine.Discrete.Vector`.

### Tier

Tier 2 per [RES-020]: cross-package, semantically substantial,
precedent-setting for the broader question "which foundational
conformance is *right* for a primitive single-Int domain value type?"
but builds on settled patterns (Phase 2b of the carrier-ecosystem
migration). Tier 3 framing was rejected because the answer is anchored
in existing DECISIONs (capability-lift-pattern v1.1.0, Phase 2b
DONE 2026-04-26).

### Scope

Single primitive package (`swift-affine-primitives`); the question
spans Tagged + Carrier + Affine — three primitive packages — and
its disposition propagates to ~20 downstream Vector / Offset consumers
(map in §Sub-Question 6).

### Prior research consulted ([RES-019] internal grep complete)

| Source | Locks in | Relevance |
|--------|----------|-----------|
| `swift-institute/Research/carrier-ecosystem-application-inventory.md` v1.2.0 RECOMMENDATION (2026-04-26) | Phase 2b: Affine.Discrete.Vector migrated to Carrier; `Affine.Discrete.Vector.\`Protocol\`` removed; operators on Carrier extension. Phase 4 Decimal Tagged refactor CANCELLED on three structural grounds. | Direct: the migration this doc audits. |
| `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` v1.0.0 RECOMMENDATION (2026-04-26) | Option G selective retention: Cardinal/Vector migrate cleanly to Carrier; Ordinal.`Protocol` retained as Carrier sibling because its operator (`Self + Self.Count`) needs a per-conformer associatedtype Carrier lacks. | Direct: explains why Vector's path differs from Ordinal's. |
| `swift-institute/Research/affine-operator-unification-completeness.md` v1.1.0 DEFERRED (2026-03-10) | Tagged+Affine operator unification deferred — not blocking. | Tangential: the deferred unification is downstream, not load-bearing for representation. |
| `swift-institute/Research/decimal-carrier-integration.md` RECOMMENDATION (2026-04-26) | Phase 4 CANCELLED: Decimal.Exponent / Precision / Payload remain standalone structs. Three structural blockers: naming-convention obstacle (no domain-typed phantom Tag), [IMPL-001] domain erasure of `Carrier<Int>`, [RES-018] second-consumer hurdle for the Tagged refactor. | Direct precedent: same role-class as Vector. |
| `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 RECOMMENDATION | Recipe + four ecosystem instances (Cardinal, Ordinal, Hash.Value, **Affine.Discrete.Vector**); Rec #3 (don't refine Carrier); Rec #6 (witness protocols stay distinct). | Direct: Vector listed as canonical adopter. |
| `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` DECISION | Tagged does not conform to RawRepresentable; phantom-Tag is the Domain discriminator at the type level. | Direct: anchors the Tagged role at the protocol layer. |

The question this document answers — *"is the Tagged approach vestigial
for Vector specifically, given Carrier?"* — was foreshadowed by the
Decimal Phase 4 cancellation but was not posed in those terms for
Vector. This doc closes that gap.

---

## Question

Should `Affine.Discrete.Vector` be represented as **Tagged-based** (a
typealias to `Tagged<Affine.Discrete.Vector.Tag, Int>` or similar) or
**Carrier-based** (a standalone struct that conforms to
`Carrier.\`Protocol\`` as a trivial-self-carrier, with phantom-typed
domain handled via `Tagged<Tag, Affine.Discrete.Vector>`)?

Per [RES-029] semantic-identity-first ranking — this is a binding /
membership question (WHAT IS Affine.Discrete.Vector?), not a
cost-vs-cohesion ranking. Tier 1 (semantic identity) dispositive; cost /
migration / aesthetics serve as tiebreakers only.

---

## Pre-Analysis Reframe

Per [RES-022] structural-correctness-first framing — the question as
posed contains a latent category error worth surfacing before option
enumeration:

**Tagged and Carrier do not occupy the same layer of abstraction.**

- **`Carrier.\`Protocol\``** is a *protocol* — the conformance contract
  that defines `associatedtype Domain` (default `Never`),
  `associatedtype Underlying`, `var underlying: Underlying { borrowing get }`,
  and `init(_:)`. It lives at
  `swift-carrier-primitives/Sources/Carrier Protocol/_CarrierProtocol.swift`.
- **`Tagged<Tag, Underlying>`** is a *concrete generic struct* — one
  implementation of `Carrier.\`Protocol\`` where the phantom `Tag` IS
  the protocol's `Domain` discriminator. See
  `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.Protocol.swift:42-67`
  (Verified 2026-05-22):

  ```swift
  extension Tagged: Carrier.`Protocol`
  where Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable {
      public typealias Domain = Tag
      public typealias Underlying = Underlying
      // ...
  }
  ```

- **`Affine.Discrete.Vector`** is also a *concrete struct* that conforms
  to `Carrier.\`Protocol\`` — but as a **trivial-self-carrier** (Domain
  defaults to `Never`, Underlying = Self). See
  `swift-affine-primitives/Sources/Affine Carrier Primitives/Affine.Discrete.Vector+Carrier.swift:11-18`
  (Verified 2026-05-22):

  ```swift
  extension Affine.Discrete.Vector: Carrier.`Protocol` {
      public typealias Underlying = Affine.Discrete.Vector
  }
  ```

Tagged and Vector are therefore not competing representations — they are
**siblings** at the same layer (both are concrete Carrier conformers),
differing in role:

| Role | Type | Domain | Underlying |
|------|------|--------|------------|
| Trivial-self-carrier | `Affine.Discrete.Vector` | `Never` (default) | `Self` |
| Generic phantom-typed carrier | `Tagged<Tag, Affine.Discrete.Vector>` | `Tag` (the phantom) | `Affine.Discrete.Vector` |

The reframed question becomes: **does the current representation
(Vector as a standalone struct + Tagged-of-Vector as the phantom-typed
form) hold up structurally, or should Vector itself be reduced to a
Tagged alias (replacing the standalone struct)?**

The handoff's "Tagged approach is vestigial" suspicion has two distinct
readings that the reframe separates:

| Reading | Claim | Disposition |
|---------|-------|-------------|
| **R1: Tagged-as-package-extraction is vestigial** | The Affine Tagged Primitives target should not be its own package. | **Correct** — the principal's 2026-05-22 revert resolved this. The Tagged operators (Tagged-Ordinal-Vector retreat, Tagged-Vector × Ratio scaling) are deeply tangled with the rest of Affine arithmetic; separate-package extraction creates no isolation. |
| **R2: Tagged-as-representation-of-Vector is vestigial** | Vector should itself be a Tagged alias (e.g., `typealias Vector = Tagged<Vector.Tag, Int>`) — Tagged would subsume Vector. | The substance of this doc. |
| **R3: Tagged-as-generic-instantiator is vestigial** | The whole Tagged generic struct could be retired; Carrier alone suffices. | **Refuted in §Analysis** — Tagged is irreducible as the phantom-typed Carrier instantiator. |

Reading R1 is already settled by the revert. Reading R3 is settled by
the Tagged: Carrier conformance machinery and Tagged's role across ~80
ecosystem aliases. Reading R2 is the structurally-substantive question
this doc answers.

---

## Analysis

### Sub-Question 1 — Current State

`Affine.Discrete.Vector` is a primitive struct, NOT a Tagged alias.
Verified 2026-05-22 against
`swift-affine-primitives/Sources/Affine Discrete Primitives/Affine.Discrete.Vector.swift:37-46`:

```swift
public struct Vector {
    public let rawValue: Int

    @inlinable
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}
```

Conformance clauses (each verified at file:line on 2026-05-22):

| Conformance | File:line | Provides |
|-------------|-----------|----------|
| `Sendable` | `Affine.Discrete.Vector.swift:58` | Cross-actor transfer |
| `==`, `<`, `<=`, `>`, `>=` (explicit Equatable/Comparable witnesses) | `Affine.Discrete.Vector.swift:65-93` | Synthesis hint at the declaring module |
| `var magnitude: Cardinal` | `Affine.Discrete.Vector.swift:100-102` | ℤ → ℕ projection |
| `CustomStringConvertible` | `Affine.Discrete.Vector.swift:107-112` | Debug formatting |
| `ExpressibleByIntegerLiteral` | `Affine.Discrete.Vector.swift:116-123` | `let v: Vector = 5` |
| `Carrier.\`Protocol\`` (trivial self) | `Affine.Discrete.Vector+Carrier.swift:11-18` | Generic Carrier dispatch |
| `Equation.\`Protocol\`` | `Affine.Discrete.Vector+Equation.Protocol.swift` | Equation witness (sibling to Carrier) |
| `Comparison.\`Protocol\`` | `Affine.Discrete.Vector+Comparison.Protocol.swift` | Comparison witness (sibling to Carrier) |
| `Hash.\`Protocol\`` | `Affine.Discrete.Vector+Hash.Protocol.swift` | Hash witness (sibling to Carrier) |
| `AtomicRepresentable` | `Affine.Discrete.Vector+AtomicRepresentable.swift` | Atomics SLI |

The arithmetic surface (`+`, `-`, `+=`, `-=`, `zero`, `one`, `prefix -`)
is on the Carrier extension, not on the Vector struct directly. See
`Affine.Discrete.Vector+Carrier.swift:22-74`:

```swift
extension Carrier.`Protocol` where Underlying == Affine.Discrete.Vector {
    public var vector: Affine.Discrete.Vector { underlying }
    public static var zero: Self { Self(Affine.Discrete.Vector(0)) }
    public static var one: Self { Self(Affine.Discrete.Vector(1)) }
    public static func + (lhs: Self, rhs: Self) -> Self { ... }
    // ... etc
}
```

This is the post-Phase-2b state per `carrier-ecosystem-application-inventory.md`
v1.2.0 — the legacy `Affine.Discrete.Vector.\`Protocol\`` capability protocol
was REMOVED; its operators were lifted onto the constrained Carrier
extension. Both bare Vector AND `Tagged<Tag, Vector>` (via the
`Tagged: Carrier` cascade) inherit the operators uniformly.

### Sub-Question 2 — Tagged Role in the Current Design

The Tagged role in Affine is multi-faceted; each role is verified
against current source 2026-05-22:

| Role | Where it lives | What Carrier alone cannot replicate |
|------|---------------|-------------------------------------|
| Phantom-Tag IS Carrier's Domain | `Tagged+Carrier.Protocol.swift:42-67` (Tagged is unconditionally Carrier with `Domain = Tag`) | Carrier alone has no struct shape — it's a protocol. Tagged provides the generic struct that instantiates the phantom-Tag axis. |
| Generic instantiator for any Tag | `extension Tagged where Underlying == Affine.Discrete.Vector` (in `Tagged+Affine.swift`) | Without Tagged, every domain-typed Vector wrapper (Text.Offset, Bit.Index.Offset, Memory.Address.Offset, etc.) would require a manual per-Tag struct + per-Tag Carrier conformance + per-Tag operators. Per [RES-018] case (b), this is domain-owned vocabulary; per [API-NAME-001], synthesizing dozens of `*Tag` types violates naming conventions. |
| `Offset` alias for Tagged-of-Ordinal | `Tagged+Affine.swift:33-62` — `extension Tagged where Underlying == Ordinal { typealias Offset = Tagged<Tag, Affine.Discrete.Vector> }` | Names the standard "displacement of this tagged ordinal" pattern; consumed at sites like `Index<Bit>.Offset`, `Text.Offset`, `Memory.Address.Offset`. Carrier alone cannot host this nested typealias because the relationship `Ordinal → Vector` is domain-specific. |
| Cross-Tag-Domain scaling via Ratio | `Tagged+Affine.swift:248-291` — `Tagged<From, V> * Ratio<From, To> → Tagged<To, V>` | The Ratio operator changes the Tag domain (From → To). Bare Carrier cannot express this because `Self.Domain` is fixed per-conformer; Tagged's generic-Tag parameter is what makes cross-Domain scaling typeable. |
| Cross-Tagged Ordinal-Vector retreat / displacement | `Tagged+Affine.swift:168-235` — `Tagged<Tag, Ordinal> - Tagged<Tag, Vector> → Tagged<Tag, Ordinal>`, `Ordinal.\`Protocol\` - Ordinal.\`Protocol\` → Tagged<Tag, Vector>` | The Tag must be preserved across the subtraction. The `Tag: ~Copyable` parameter on `extension Tagged where Underlying == Ordinal` does this without per-Tag boilerplate. |
| SLI surface | `Affine Primitives Standard Library Integration/` — `UnsafePointer+Tagged.Ordinal`, `UnsafeRawPointer+Affine.Discrete.Vector`, `RandomAccessCollection+Tagged.Ordinal.Offset`, `Int+Affine.Discrete.Vector` | Pointers / collections take Tagged-of-Vector offsets to preserve phantom-Tag domain through pointer arithmetic. Carrier alone cannot express phantom-Tag-preserving pointer arithmetic without Tagged. |

**Finding 2.1**: Tagged's role in Affine is **load-bearing across five
distinct surfaces** (Carrier instantiation, Offset alias, Ratio scaling,
Tagged-Ordinal arithmetic, SLI). None of these surfaces can be
expressed via Carrier alone — they all require a *generic struct
parameterized over an arbitrary Tag*, which is exactly Tagged.

### Sub-Question 3 — Carrier Alternative

The Carrier-only representation is ALREADY IN PLACE (Phase 2b DONE).
Three observations:

1. `Affine.Discrete.Vector: Carrier.\`Protocol\`` with `Underlying = Self`
   is the trivial-self-carrier shape. Arithmetic on the Carrier
   extension applies to both bare Vector and Tagged-of-Vector uniformly.
2. The legacy `Affine.Discrete.Vector.\`Protocol\`` capability protocol
   was removed (per `operator-ergonomics-and-carrier-migration.md`
   Recommendation Option G). No re-introduction is recommended — its
   operators (Self+Self → Self) have no per-conformer associatedtype
   dependency.
3. No additional Carrier refinement (e.g., an `Equation.Protocol` shape)
   is needed on top of Carrier for Vector specifically — the witness
   protocols (Equation, Hash, Comparison) are siblings to Carrier per
   Recommendation #6 and already in place at separate files.

The Carrier alternative IS the current shape. The question is whether
to PRESERVE it as-is or to REDUCE Vector to a Tagged alias (sub-Q4).

### Sub-Question 4 — Tagged-Uniquely-Provides (if anything)

The substantive question. If we hypothetically replaced
`Affine.Discrete.Vector` with `typealias Vector = Tagged<Vector.Tag, Int>`,
what would we lose?

**Loss 1 — Spec-mirroring semantic identity per [API-NAME-003]**:

`Affine.Discrete.Vector` is the spec-mirroring name: the displacement
in discrete affine geometry per the mathematical definition (Vec = a
directed distance between two Positions). The name carries semantic
weight independent of its underlying Int representation. Reducing
Vector to `Tagged<Vector.Tag, Int>` would force a synthesized
`Vector.Tag` phantom type — there is no natural domain-typed phantom
candidate (Vector is not a typed-domain of something else; it IS the
domain).

This is the same naming-convention obstacle that cancelled the Decimal
Phase 4 refactor per `decimal-carrier-integration.md`. The synthesized
`*Tag` types violate [API-NAME-*] because they exist only to satisfy
Tagged's signature, not to encode a real domain.

**Loss 2 — [IMPL-001] domain erasure**:

`Tagged<Vector.Tag, Int>` exposes Int as the Underlying. Operations
that should be denied at Vector's domain boundary (e.g., bit shifting,
Int's overflow operators, Int's `BinaryInteger` protocol family) would
become available via the Tagged → Int unwrap path. Vector's arithmetic
identity is the type's primary purpose; treating it as a tagged Int
erases that identity.

**Loss 3 — Tagged-cascade asymmetry**:

If `Vector = Tagged<Vector.Tag, Int>`, then `Tagged<Tag, Vector>` would
become `Tagged<Tag, Tagged<Vector.Tag, Int>>` — a NESTED Tagged. The
Tagged: Carrier conformance is "immediate Underlying, no cascade" per
`Tagged+Carrier.Protocol.swift:39-49`:

> `Tagged<Tag, U>.Underlying == U`. For nested `Tagged<X, Tagged<Y, Int>>`,
> `.Underlying == Tagged<Y, Int>` (the immediate wrapped type) — to reach
> `Int`, recurse.

The current `extension Carrier.\`Protocol\` where Underlying == Affine.Discrete.Vector`
relies on Vector being the immediate Underlying. With Vector reduced
to `Tagged<Vector.Tag, Int>`, the constrained extension would need to
re-spell to either `Underlying == Tagged<Vector.Tag, Int>` (verbose,
implementation-leaking) or `Underlying == Int` (which would erase the
Vector-vs-Cardinal distinction at the protocol level — both are
Ints — and break the explicit `+ - * /` operator dispatch that
distinguishes Vector arithmetic from Cardinal arithmetic).

**Loss 4 — Ratio scaling type signature**:

`Affine.Discrete.Ratio<From, To>` is a multi-axis morphism between
typed domains. The current `Tagged<From, Vector> * Ratio<From, To> → Tagged<To, Vector>`
operator typechecks because Vector is a discrete, monomorphic type. If
Vector were `Tagged<Vector.Tag, Int>`, the operator's signature would
become `Tagged<From, Tagged<Vector.Tag, Int>> * Ratio<From, To> → Tagged<To, Tagged<Vector.Tag, Int>>`
— legible only to compiler diagnostics, not to humans.

**Loss 5 — `[RES-018]` second-consumer hurdle (inverse direction)**:

The hypothesis "Vector should be a Tagged" requires identifying a
second consumer that benefits from Vector being Tagged-shaped. None
exists. Vector's only role IS to be the discrete-affine-displacement
type. The benefit of Tagged-of-Int (compile-time domain distinction)
is unrelated to Vector's role (encoding a specific arithmetic identity).

**Finding 4.1**: Tagged-uniquely-provides phantom-Tag domain
instantiation. Tagged-of-Vector serves that role correctly. Vector
itself becoming a Tagged would lose four distinct properties: spec
naming, domain protection, immediate-Underlying simplicity, and
type-signature legibility. The change has no offsetting benefit.

### Sub-Question 5 — Carrier-Uniquely-Provides

Carrier provides the *abstraction* — the conformance contract that
unifies generic dispatch across (a) bare Vector, (b) Tagged-of-Vector
for arbitrary Tags, and (c) any future Vector-Carrying type a downstream
might introduce. This is the dispatch surface that the Phase 2b
migration deliberately consolidated.

`extension Carrier.\`Protocol\` where Underlying == Affine.Discrete.Vector`
is the canonical place for Vector arithmetic — both bare Vector and
Tagged-of-Vector inherit identically. The verification (per Phase 2b
implementation log): all bare-Vector arithmetic AND
Tagged-of-Vector arithmetic resolve via the same Carrier extension;
no per-type duplication.

This is the property the principal's Phase 2b migration captured. It
remains intact under the current shape.

### Sub-Question 6 — Ecosystem Impact

Downstream consumers of Affine.Discrete.Vector / Tagged-of-Vector
enumerated 2026-05-22 via workspace grep across `swift-primitives/`,
`swift-standards/`, `swift-foundations/`:

Direct `Affine_Discrete_Primitives` / `Affine_Tagged_Primitives` /
`Affine_Carrier_Primitives` imports (excluding swift-affine-primitives
itself):

| Package | Form of dependence |
|---------|--------------------|
| swift-ordinal-primitives | `Ordinal.Distance` uses Vector |
| swift-cardinal-primitives | Cardinal-Vector arithmetic |
| swift-affine-geometry-primitives | Continuous Affine layer (Point, Translation, Transform) depends on Discrete primitives |
| swift-algebra-affine-primitives | Group conformance on `Affine.Discrete.Vector+Group.swift` |
| swift-algebra-modular-primitives | `Algebra.Modular+Advanced.swift` |
| swift-memory-primitives | `Memory.Address.swift` — Address-as-Tagged-Ordinal pattern uses Tagged.Offset |
| swift-index-primitives | `Index<T>.Offset` cascade (per the 2026-04-30 migration noted in `index-offset-arithmetic`'s SUPERSEDED experiment) |
| swift-bit-index-primitives | `Bit.Index+Byte.swift`, `Bit+Affine.Discrete.Ratio.swift` consume Index.Offset + Ratio |
| swift-bit-pack-primitives | `Bit.Pack.Location` |
| swift-bit-vector-primitives | `Bit.Vector.Bounded` family imports Affine_Primitives |
| swift-collection-primitives | `Collection.Rotated` |
| swift-tensor-primitives | `Tensor.Strides+Order`, `Tensor.Index+Linearize`, `Tensor.Strides` |
| swift-text-primitives | `Text.Offset` typealias |
| swift-argument-primitives | `Argument.Position` |
| swift-input-primitives | `advance-by-offset-vs-count` |
| swift-clock-primitives | `instant-affine-arithmetic` |
| swift-geometry-primitives | `Geometry.{Arc, Ball, Ellipse, Line}` |
| swift-symmetry-primitives | Symmetry tests |

(~18 distinct package consumers; the prevalent surface is
`Tagged<Tag, Affine.Discrete.Vector>` via the `.Offset` alias and
`Affine.Discrete.Ratio<From, To>` for cross-domain scaling.)

**Finding 6.1**: A Tagged-based Vector refactor would touch every one
of these packages because the Vector type signature would change at
every consumer site. The migration cost is non-trivial, but per
[RES-022] is a tiebreaker only — structural correctness is
load-bearing.

### Sub-Question 7 — Migration Cost

Pre-1.0 there are no hard API stability constraints. The migration
hypothesis (Vector → Tagged-of-Int) would require:

- Update Vector declaration in `Affine.Discrete.Vector.swift`
  (delete struct, replace with typealias).
- Audit every constrained `Carrier.\`Protocol\``-extension whose clause
  reads `Underlying == Affine.Discrete.Vector`: ~10 declarations across
  Affine Carrier / Hash / Equation / Comparison / Tagged / SLI / Arithmetic
  / Composition / Quotient targets.
- Update every consumer's type spelling: `Affine.Discrete.Vector` and
  `Tagged<Tag, Affine.Discrete.Vector>` at ~50-100 call sites across
  the 18 consumer packages enumerated above.
- Update `Affine.Discrete.Ratio<From, To>` operator signatures (Ratio
  acts on Vectors; the type currently encodes "Vector" structurally).
- Update SLI surface (`Affine.Discrete.Vector+AtomicRepresentable`,
  `Int+Affine.Discrete.Vector`, `RandomAccessCollection+Tagged.Ordinal.Offset`,
  etc. — ~8 SLI files).

Estimate: 60-120 commits across 18+ packages, with the structural
shape change being load-bearing at every site. Per [RES-022], even at
pre-1.0 with no API stability constraint, the migration is justified
ONLY if the resulting shape is structurally superior. It is not — per
§4 (Loss 1-5) — so the migration cost is dispositive against the
refactor.

### Sub-Question 8 — Concrete Recommendation

**Recommendation: Carrier-based — status quo. No representation change.**

`Affine.Discrete.Vector` remains a primitive struct conforming to
`Carrier.\`Protocol\`` as a trivial-self-carrier. `Tagged<Tag, Affine.Discrete.Vector>`
remains the canonical phantom-typed-domain instantiation, conforming
to `Carrier.\`Protocol\`` via the unconditional `Tagged: Carrier`
extension with `Domain = Tag`. The Affine Carrier + Tagged sub-namespace
targets remain inside `swift-affine-primitives` (per 2026-05-22 revert,
already done).

The "Tagged is vestigial" suspicion — under all three readings — does
not survive structural scrutiny:

- **R1 (package extraction)**: ALREADY DISPOSITIONED — the 2026-05-22
  revert is correct.
- **R2 (Vector-as-Tagged-alias)**: REJECTED — same structural blockers
  as Decimal Phase 4 (naming, domain erasure, second-consumer absence)
  plus additional Tagged-cascade and Ratio-signature regressions.
- **R3 (Tagged generic itself)**: REJECTED — Tagged is irreducible as
  the phantom-typed Carrier instantiator across ~80 Tagged-aliased
  sites and the 18-package Vector consumer fan-out.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-22).

### Decision

| Axis | Decision |
|------|----------|
| Vector representation | **Standalone struct** (current); conforms to `Carrier.\`Protocol\`` as trivial-self-carrier |
| Tagged role | **Retained** — generic phantom-typed Carrier instantiator; load-bearing across 5 surfaces |
| Affine Tagged Primitives target | **Stays inside swift-affine-primitives** (per 2026-05-22 revert); no separate package |
| Package extraction (Carrier + Ordinal + Tagged sub-targets) | **REVERTED** (already done by principal 2026-05-22) |

### Why This Reads as "Tagged is Vestigial" When It Isn't

The likely source of the "Tagged is vestigial" intuition:

- The Tagged operators in `Tagged+Affine.swift` look like a long file of
  boilerplate when scanned in isolation.
- Phase 2b migrated Cardinal / Vector cleanly to Carrier — that was
  the dominant signal in the 2026-04-26 commit cohort.
- The remaining Tagged-of-Vector machinery (Offset alias, cross-domain
  Ratio operators, Tagged-Ordinal-Vector retreat) could superficially
  look "left over" from before Phase 2b.

But each operator in `Tagged+Affine.swift` (audited above in §
Sub-Question 2) does work Carrier cannot replicate:

- The Offset alias names a phantom-typed domain pattern that requires
  Tagged.
- The Ratio multiplication is inherently cross-Domain (From → To); the
  result type must be a different Carrier-conformer in a different
  Domain. Tagged is the generic struct that realizes "Carrier of V
  with arbitrary Domain Tag."
- The Tagged-Ordinal-Vector retreat preserves the phantom Tag across
  the subtraction — only achievable via Tagged's generic Tag parameter.

These are not vestigial. They are domain-specific surface area that
Tagged uniquely supports.

### What This Document Does NOT Do

- Modify any source file. Research-only per dispatch scope.
- Re-litigate Phase 2b migrations (Cardinal / Vector to Carrier;
  Ordinal.`Protocol` retained as sibling). Those DECISIONS stand.
- Propose changes to Tagged's protocol-level shape (no cascade, immediate
  Underlying). The 2026-04-30 cascade-removal in
  `Tagged+Carrier.Protocol.swift:1-26` stands.
- Propose changes to Carrier's protocol-level shape. The current
  shape (`associatedtype Domain = Never`, `associatedtype Underlying`,
  `var underlying`, `init(_:)`) stands.
- Audit the `Tagged+Affine.swift` file for opportunities to lift
  individual operators onto Carrier extensions instead of Tagged
  extensions — that is downstream cosmetic, not structural; queued in
  §Follow-Up Questions if a future arc wants to pursue.

### Constraints honored

- [API-NAME-001/003] spec-mirroring identity preserved (Vector remains
  the discrete-affine-displacement name).
- [IMPL-001] domain-erasure avoided (Vector ≠ Tagged-of-Int).
- [RES-018] second-consumer hurdle respected (no premature primitive
  shifts).
- [RES-022] structural correctness drove the decision; migration cost
  cited only as tiebreaker confirming the structural verdict.
- [RES-029] semantic-identity-first ranking applied — Vector IS-A
  primitive struct conforming to Carrier; NOT-A Tagged alias.
- The 2026-05-22 reversion of commit `8e01ee3` is independently
  affirmed by this analysis.

---

## Follow-Up Questions Surfaced

1. **Tagged+Affine operator audit for cosmetic Carrier lifting (downstream
   cosmetic, low priority)**: Some operators in `Tagged+Affine.swift`
   could in principle move from `extension Tagged where Underlying == X`
   to `extension Carrier.\`Protocol\` where Underlying == X`,
   covering both bare Vector AND Tagged-of-Vector uniformly. Per
   `affine-operator-unification-completeness.md` v1.1.0 DEFERRED
   (2026-03-10), the deferred operators are Ordinal-Ordinal→Vector
   and Tagged-Ordinal-Tagged-Vector. Audit only — not blocking; revisit
   at next Affine major audit.

2. **Memory.Address-as-Tagged-Ordinal generalization**: Memory.Address
   is `Tagged<Memory, Ordinal>` (per `carrier-ecosystem-application-inventory.md`
   v1.2.0 §Section E). Address.Offset would naturally be
   `Tagged<Memory, Affine.Discrete.Vector>`. Verify the spelling
   propagates correctly; small follow-up to confirm.

3. **Capability-lift-pattern.md v1.1.0 §"Existing ecosystem instances"
   table amendment**: Per `carrier-ecosystem-application-inventory.md`
   v1.2.0 Finding A.1, that doc's ecosystem-instances list should add
   `Affine.Discrete.Vector` as a fourth canonical adopter. Documentation
   accuracy; no code change.

4. **Decimal Phase 4 re-examination under [RES-018] case (b)**: The
   Phase 4 cancellation cited [RES-018] second-consumer hurdle as one
   blocker. With the [RES-018] amendment that introduced case (b)
   domain-owned-vocabulary scope carve-out (2026-05-14), the second-
   consumer hurdle no longer applies to Decimal's role-class. The
   other two structural blockers (naming, domain erasure) remain
   load-bearing. Audit-only; no expected outcome change but the
   cancellation rationale should be re-stated under current rule
   wording.

5. **Tagged-vs-Property carrier overlap (orthogonal, future)**:
   Property<Tag, Base> was identified in `carrier-ecosystem-application-inventory.md`
   v1.2.0 §Section I as a structurally-isomorphic-to-Tagged Q2 carrier
   for ~Copyable Base. The two coexist; whether they could converge
   (Property as a Tagged variant, or Tagged as a Property variant) is
   out-of-scope here but surfaced as a future arc.

---

## References

### Primary sources (verified 2026-05-22)

- `swift-affine-primitives/Sources/Affine Discrete Primitives/Affine.Discrete.Vector.swift:37-46` — Vector struct declaration.
- `swift-affine-primitives/Sources/Affine Carrier Primitives/Affine.Discrete.Vector+Carrier.swift:11-74` — Carrier conformance + per-type accessor + constants + arithmetic.
- `swift-affine-primitives/Sources/Affine Tagged Primitives/Tagged+Affine.swift:33-291` — Tagged-of-Vector surface (Offset alias, magnitude, conversion inits, retreat, Cardinal-conversion, displacement, Ratio scaling).
- `swift-affine-primitives/Sources/Affine Discrete Primitives/Affine.Discrete.Ratio.swift:12-98` — Ratio<From, To> declaration.
- `swift-affine-primitives/Sources/Affine Discrete Primitives/Affine.Discrete.swift:12-31` — Affine.Discrete namespace.
- `swift-carrier-primitives/Sources/Carrier Primitive/Carrier.swift:1-21` — Carrier namespace.
- `swift-carrier-primitives/Sources/Carrier Protocol/Carrier.Protocol.swift:1-18` — Carrier.`Protocol` typealias.
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:54-95` — Tagged struct declaration.
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.Protocol.swift:42-67` — Tagged: Carrier conformance.
- `swift-affine-primitives` git log: `8e01ee3` (extraction) → `4a909e8` (revert) on 2026-05-22.

### Prior research (cited, not relitigated)

- `swift-institute/Research/carrier-ecosystem-application-inventory.md` v1.2.0 RECOMMENDATION (2026-04-26).
- `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` v1.0.0 RECOMMENDATION (2026-04-26).
- `swift-institute/Research/decimal-carrier-integration.md` RECOMMENDATION (2026-04-26).
- `swift-institute/Research/affine-operator-unification-completeness.md` v1.1.0 DEFERRED (2026-03-10).
- `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.1.0 RECOMMENDATION.
- `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` DECISION.

### Convention sources

- **[API-NAME-001]** — Namespace.Name nested-type convention.
- **[API-NAME-003]** — Specification-mirroring identity.
- **[IMPL-001]** — Domain-erasure forbidden at Underlying boundary.
- **[RES-001]** — Investigation triggers.
- **[RES-018]** — Premature cross-cutting primitive anti-pattern (with case (b) domain-owned vocabulary carve-out).
- **[RES-019]** — Step-0 internal research grep.
- **[RES-020]** — Tier classification.
- **[RES-022]** — Structural-correctness recommendation framing.
- **[RES-023]** — Empirical-claim verification for dependent-package state.
- **[RES-029]** — Framing-challenge for binding / membership / placement questions.

### Memory cross-references

- `project_tagged_primitives_sli_carveout.md` — Tagged SLI scope.
- `project_tagged_primitives_fork_heritage.md` — Tagged is a git-fork of pointfreeco/swift-tagged.
- `feedback_correctness_and_evergreen.md` — structural correctness + evergreen guide adoption.
