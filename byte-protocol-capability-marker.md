# Byte.Protocol as Capability Marker — Generalization, UInt8 Conformance, and Meta-Pattern Status

<!--
---
version: 1.1.0
last_updated: 2026-05-15
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
applies_to: [swift-byte-primitives, swift-cardinal-primitives, swift-ordinal-primitives, swift-affine-primitives, swift-carrier-primitives, future-byte-domain-types]
normative: true
depends_on:
  - swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md
  - swift-institute/Research/phantom-typed-value-wrappers-literature-study.md
  - swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md
  - swift-institute/Research/cardinal-protocol-unification-memo.md
  - swift-institute/Research/byte-primitive-extraction-and-domain-naming.md
---
-->

## Context

The byte-extraction arc (recorded in `byte-primitive-extraction-and-domain-naming.md` v1.0.1, DECISION, 2026-05-15) landed `Byte.Protocol` in `swift-byte-primitives`:

```swift
extension Byte {
    public protocol `Protocol`:
        Carrier.`Protocol`,
        Sendable, Equatable, Hashable, Comparable, ExpressibleByIntegerLiteral
        where Underlying == UInt8 { }
}
extension Byte: Byte.`Protocol` {}
```

The arc deferred two questions to this Tier 3 session per `HANDOFF-byte-protocol-capability-marker.md`:

1. **Should `UInt8` conform to `Byte.Protocol`?** Conformance enables generic byte algorithms over raw `UInt8` without wrapping; non-conformance protects against shadowing stdlib operators and against `Byte.Protocol`-typed APIs surfacing in arbitrary `UInt8` use sites.
2. **Is `Byte.Protocol` instantiating a general pattern worth naming/promoting?** Other candidates with the same shape — `Char.Protocol`, `Codepoint.Protocol`, `Line.Protocol`, `Word.Protocol` — could each follow the recipe of refining `Carrier.Protocol<T>` with stdlib basics. If the recipe IS general, formalizing it (skill rule, generator macro, meta-protocol) saves rediscovery for every future value-type primitive.

These are precedent-setting questions whose answers will shape every subsequent L1 value-type primitive. The decision here is what makes this Tier 3 ([RES-020]): the cost-of-error is high, the expected lifetime is timeless, the affected surface is ecosystem-wide.

## Sub-Questions

| ID | Question | Audience |
|----|----------|----------|
| Q1 | Should `UInt8` conform to `Byte.Protocol`? | swift-byte-primitives author; institute reviewer |
| Q2 | Is the Byte.Protocol shape a general pattern worth naming/promoting? If so, in what form (skill rule, generator macro, meta-protocol)? | every future L1 value-type-primitive author |

Q1 and Q2 are entangled: the answer to "should the recipe generalize" partly determines the answer to "should the underlying stdlib type conform." Both are addressed below.

## Prior Art

Two strands of prior art bear on the decision: internal research the institute has already produced on phantom-typed wrappers and capability-marker patterns, and external prior art (Rust, Haskell, Scala, Swift Numeric) covering how other ecosystems handle the same recurring question.

### 1. Internal Prior Art

The internal corpus is more authoritative for this question than the external survey, per [RES-019] (Step-0 Internal Research Grep — internal research governs pending explicit override). Four documents are load-bearing.

#### 1.1 The Group A / Group B Taxonomy

[`property-tagged-semantic-roles.md`](../../swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md) v1.1.0 (RECOMMENDATION, 2026-04-23, Tier 2, cross-package scope) names the canonical taxonomy:

> **Group A — Domain identity.** The phantom tag represents the ontological domain of the wrapped value. Different tags mean different kinds of thing. Examples: `Tagged<Bytes, Cardinal>`, `Tagged<Frames, Cardinal>`, bare `Cardinal`. Connected fibers — admits `retag<NewTag>(_:)` as the cross-fiber morphism.
>
> **Group B — Verb / operation namespace.** The phantom tag selects which operations apply. Different tags mean the same wrapped value with different API surfaces. Examples: `Property<Stack.Push, Stack>`, `Property<Stack.Pop, Stack>`. Sealed fibers — no cross-fiber morphism (retagging Push to Pop is semantically nonsensical).

The doc's §"Categorical asymmetry" establishes that **Group A admits a super-protocol *in principle***; Group B does not. The reason is fibration structure: Group A's fibers are connected by a uniform Tag-discriminator space (Bytes and Frames are types with meaning across the ecosystem); Group B's fibers are sealed because each Tag is container-local (Stack.Push and Deque.Push are independent empty enums sharing only a name).

**`Byte.Protocol` is unambiguously Group A.** Its conformers (`Byte`, and any future `ASCII.Code` / `Latin1.Byte` / `UTF8.Code_Unit`) all carry uniform meaning across instances. They differ in domain identity, not in verb namespace. The taxonomy's Group A clause directly applies.

#### 1.2 The Per-Type X.Protocol Pattern Is Already Decided

[`protocol-abstraction-for-phantom-typed-wrappers.md`](./protocol-abstraction-for-phantom-typed-wrappers.md) v1.4.0 (Tier 3, DECISION, IMPLEMENTED, 2026-02-13) is the institute's canonical decision on how to abstract over bare-vs-Tagged operator pairs. The decision §"The Protocol Abstraction Pattern (Phased)" prescribes:

> For each base type `T` used as a `Tagged` `RawValue`, define **`T.Protocol`** — a protocol in `T`'s package with `var t: T { get }` projection and `init(_ t: T)` injection; self-conformance `T : T.Protocol`; Tagged conformance `Tagged<Tag, T> : T.Protocol where RawValue == T, Tag: ~Copyable`.

The doc explicitly evaluated and **rejected** the unified-protocol alternative (Option I: top-level `Taggable<Value>`). The rejection reason: a generic name (Taggable, RepresentedBy, Representable, Transparent) trades domain meaning for generality, and no candidate is satisfactory; `Cardinal.Protocol` self-documents in a way `Taggable<Cardinal>` does not.

`Byte.Protocol` instantiates this exact pattern, with one adaptation:
- The base type is `Byte`, not Cardinal/Ordinal/Vector — but the recipe transfers without modification because Byte is itself a `Carrier.Protocol` conformer with a clear underlying type (`UInt8`).
- Byte.Protocol uses the **sibling-to-Carrier** form (`var byte: Byte { get }` + `init(_ byte: Byte)`), mirroring `Ordinal.Protocol`. The sibling shape is structurally required for recursive Tagged conformance: Tagged's universal `Tagged: Carrier.Protocol` conformance sets `Tagged<Tag, X>.Underlying == X` (the immediate generic parameter), so `Tagged<Tag, Byte>.Underlying == Byte`, not `UInt8`. A refinement form (`: Carrier.Protocol where Underlying == UInt8`) would constrain every conformer's Carrier.Underlying to equal UInt8 — admitting `Tagged<Tag, UInt8>` but blocking `Tagged<Tag, Byte>`, which is the natural wrapping shape consumers expect (`Tagged<DeviceID, Byte>`, parallel to `Tagged<Tag, Cardinal>`). The sibling protocol decouples the byte-domain accessor (`byte: Byte`) from the carrier-storage accessor (`underlying: UInt8` on Byte itself), letting any conformer answer "what byte do you carry?" without forcing its Carrier.Underlying to equal UInt8. (See §"Recursion-vs-refinement constraint principle" below.) Both variants — sibling-to-Carrier (Cardinal, Ordinal, Byte) and refinement-of-Carrier (none in production after this resolution) — are formally within the same recipe family, but only the sibling variant supports recursive Tagged conformance, so the practical recipe collapses to the sibling form in every Group A capability marker.

#### 1.2.1 Recursion-vs-Refinement Constraint Principle

**The constraint** (added v1.1.0 — discovered when landing the Tagged-recursive conformance):

> A refinement-of-Carrier X.Protocol (`X.Protocol: Carrier.Protocol where Underlying == U` for some concrete `U`) blocks recursive Tagged conformance because `Tagged<Tag, X>.Underlying == X` (per Tagged's universal Carrier conformance with `typealias Underlying = Underlying` — the immediate generic param), not `U`. Use the sibling form (`X.Protocol` with its own `var x: X { get }` accessor and `init(_ x: X)`) when recursive Tagged conformance is needed or anticipated.

This is the decision principle for sibling-vs-refinement choices in the per-domain recipe: if the X.Protocol is intended to admit `Tagged<Tag, X>` as a conformer (the natural shape for phantom-tagged X-domain values), it MUST be the sibling form. Refinement-of-Carrier is only viable for X.Protocols that explicitly do not need Tagged-recursive participation — a rare case in the Group A capability-marker family, since Group A members are precisely the types that compose with Tagged at the consumer surface.

#### 1.3 Live-Fire Precedent: The Cardinal.Protocol Sibling

[`cardinal-protocol-unification-memo.md`](./cardinal-protocol-unification-memo.md) (SUPERSEDED 2026-05-04 by `cardinal-trivial-self-revert-plan.md`; supersession note carries the working architecture) is the proof-of-pattern. The supersession §"Decision (2026-05-04)" records the canonical Cardinal.Protocol shape now in production:

```swift
extension Cardinal {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable = Never
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}
extension Cardinal: Cardinal.`Protocol` { ... }
extension Tagged: Cardinal.`Protocol`
where Underlying: Cardinal.`Protocol`, Tag: ~Copyable { ... }
```

The §"Migration outcome" enumerates six packages cleanly migrated to this pattern: `swift-ordinal-primitives`, `swift-affine-primitives`, `swift-cyclic-primitives`, `swift-sequence-primitives`, `swift-finite-primitives`, `swift-bit-vector-primitives`. Net deletion: ~115 lines across all six packages. Each package's bare-vs-Tagged operator split collapsed to a single signature generic over `Cardinal.Protocol`.

**Critically: `UInt` does NOT conform to `Cardinal.Protocol`.** Bare `Cardinal` does; `Tagged<Tag, Cardinal>` does (recursively, when `Underlying: Cardinal.Protocol`); `UInt` does not. The stdlib `UInt` is the *Underlying carrier* (via `swift-carrier-primitives`' standard-library integration target's `extension UInt: Carrier.Protocol`), but it does not carry the Cardinal-domain capability bundle. This is the precedent that Q1 inherits.

#### 1.4 Sibling-vs-Refinement Pattern Distinction

[`Ordinal.Protocol.swift`](../../swift-primitives/swift-ordinal-primitives/Sources/Ordinal%20Primitives%20Core/Ordinal.Protocol.swift):1–17 documents the sibling-vs-refinement choice explicitly:

> `Ordinal.\`Protocol\`` is a SIBLING to `Carrier.\`Protocol\`<Ordinal>` (not a refinement). Its sole reason to exist is the `associatedtype Count: Carrier.\`Protocol\`<Cardinal>` machinery — per-conformer concrete `Count` is what makes `slot + .one` infer cleanly at call sites. `Carrier.\`Protocol\`<Ordinal>` conformance handles the cross-type generic-dispatch role; this protocol handles the operator-ergonomics role. Both protocols coexist on the same conforming types — same precedent as `Hash.\`Protocol\``, `Equation.\`Protocol\``, `Comparison.\`Protocol\`` coexisting with Carrier per capability-lift-pattern.md Recommendation #6.

And [`Byte.Protocol.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol.swift) (file header, post-v1.1.0 refactor) documents the same pattern:

> Byte.Protocol is a SIBLING protocol to Carrier.\`Protocol\` — not a refinement. The sibling shape is what makes recursive Tagged conformance work: extension Tagged: Byte.\`Protocol\` where Underlying: Byte.\`Protocol\`, Tag: ~Copyable { ... }. … Pattern parallels swift-ordinal-primitives' Ordinal.\`Protocol\` (sibling to Carrier with ordinal: Ordinal accessor).

Earlier revisions of Byte.Protocol used the refinement form (`: Carrier.Protocol where Underlying == UInt8`); the refactor to sibling form was driven by §1.2.1's recursion-vs-refinement constraint principle.

#### 1.5 The Carrier-Walkback Reflection ([IMPL-102])

[`2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md`](./Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md) records a deferred lesson directly applicable to Q2. The reflection's Pattern 1:

> **Academic framing is necessary but not sufficient for language-specific design.** The Carrier proposal was categorically clean (free-Carrier adjunction, fibration structure, parametricity justification — all correctly grounded in cited literature). It failed on a distinctly Swift concern: overlapping conditional conformances are forbidden, and the universal "Tagged is a Carrier" extension would need recursive-via-Carrier extensions that conflict with per-Underlying extensions.

The rule extracted as [IMPL-102]:

> When proposing a super-protocol or cross-type abstraction in Swift, the gating question is "does this require overlapping conditional conformances to express fully?" If yes, the abstraction is incomplete in Swift regardless of its theoretical beauty.

This rule prejudges Q2's "Option C: introduce a meta-protocol `Carrier.Protocol.WithStdlibBasics` or similar" — that path was investigated by the capability-lift family of docs (now lost to a mid-session file disturbance per the reflection's Part 9; the supersession history survives in cross-references at [`property-tagged-semantic-roles.md`](../../swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md) §"Categorical asymmetry" + §"Fibration view"). The verdict carried forward: Group A admits a super-protocol *in principle* but Swift's overlapping-conformance rules force the implementation to be incomplete. The per-type pattern is the working alternative.

### 2. External Prior Art

The external survey adds context for the design-space evaluation but is not the determining factor — the internal corpus has already converged on the relevant decisions. Per [RES-019], internal research governs.

The foundational external prior art on phantom-typed wrappers is comprehensively covered in [`phantom-typed-value-wrappers-literature-study.md`](./phantom-typed-value-wrappers-literature-study.md) v1.0.0 (Tier 3 SLR, 36 papers, RECOMMENDATION, 2026-02-26). That study spans Reynolds parametricity (1983), Wadler free theorems (1989), Hinze "Fun with Phantom Types" (2003), Cheney & Hinze first-class phantom types (2003), Fluet & Pucella phantom subtyping (2006), Breitner et al. safe zero-cost coercions for Haskell (2014), and cross-language comparison across Haskell / Rust / OCaml / TypeScript / Swift. This document does NOT re-derive that material. The treatment below focuses on the *specific* sub-question the handoff brief raises — capability addition to a stdlib primitive type — which the foundational SLR does not address directly.

#### 2.1 Rust: Trait Coherence, Orphan Rules, and the Newtype Pattern

**Verified citations** (Rust Book, https://doc.rust-lang.org/book/):

The orphan rule, from ch10-02 "Implementing a Trait on a Type":

> We can implement a trait on a type only if either the trait or the type, or both, are local to our crate. … This restriction is part of a property called *coherence*, and more specifically the *orphan rule*, so named because the parent type is not present. This rule ensures that other people's code can't break your code and vice versa. Without the rule, two crates could implement the same trait for the same type, and Rust wouldn't know which implementation to use.

For Q1 in Rust terms: would `impl Byte_Protocol for u8` be allowed if `Byte_Protocol` is local? **Yes** — orphan rule permits it because the trait is local. But ch20-02 "Using the Newtype Pattern to Implement External Traits on External Types" documents the canonical workaround for the *symmetric* hard case AND the typical idiom even when the orphan rule permits:

> [The orphan rule] states we're only allowed to implement a trait on a type if either the trait or the type, or both, are local to our crate. It's possible to get around this restriction using the newtype pattern, which involves creating a new type in a tuple struct. … No runtime performance penalty — the wrapper type is elided at compile time.

The Rust community pattern: when capability semantics differ from the carrier type's stdlib semantics, wrap-and-conform rather than impl-on-foreign-type, even when the orphan rule doesn't strictly forbid the latter. The newtype is the discipline that prevents method shadows, lets the wrapper opt into different trait sets per wrapper, and keeps the foreign type's API surface uncluttered for clients who don't want the new capability.

**Application to Q1**: Rust's orphan rule does NOT mechanically forbid `UInt8: Byte.Protocol` in Swift terms (Swift has no orphan rule; conformance can be added in any module). But the Rust idiom — wrap-and-conform via newtype rather than impl-on-foreign-type — matches the institute's existing precedent (Cardinal wraps UInt; Byte wraps UInt8; neither stdlib type conforms to the institute's domain protocol).

#### 2.2 Haskell: Typeclass Composition and the Newtype Convention

The Haskell typeclass system's superclass hierarchy on numeric types follows a layered shape:

- `class Eq a` — equality
- `class Eq a => Ord a` — ordering refines equality
- `class Show a` — string rendering (independent)
- `class (Eq a, Show a) => Num a` — numeric refines Eq + Show
- `class (Num a, Ord a) => Real a`
- `class (Real a, Enum a) => Integral a`

This is the closest in-language analog to Swift's `Numeric` hierarchy. Numeric primitives (`Int`, `Word8` ≈ Swift's `UInt8`) instance every applicable typeclass in the hierarchy directly on the bare type. The Haskell ecosystem treats stdlib primitives as the canonical instance of `Num`, `Ord`, `Show`, `Eq`.

But the **newtype convention** (verified citation, HaskellWiki/Newtype, https://wiki.haskell.org/Newtype):

> If you want to declare different type class instances for a particular type, or want to make a type abstract, you can wrap it in a `newtype` and it'll be considered distinct to the type-checker, but identical at runtime. … The two types can be treated essentially the same, without the overhead or indirection normally associated with a data constructor.

The convention applies when a *different* set of typeclass instances is wanted for a structurally-identical value. The canonical example: `Sum` and `Product` are newtype wrappers around numeric types that change the `Monoid` instance — `Sum 3 <> Sum 4 = Sum 7`; `Product 3 <> Product 4 = Product 12`. Both wrap the same underlying `Int`; neither IS the underlying `Int` for the purposes of monoidal composition.

**Application to Q1**: Byte.Protocol's relationship to UInt8 matches the `Sum`/`Product`-vs-`Int` shape, not the `Int: Num` direct-instance shape. Byte adds byte-domain operations (bitwise, hex-rendering via downstream encoders, parser-input shape) that are *not* the stdlib's UInt8 operations (arithmetic, comparison, integer-literal). The two surfaces are intentionally different. By Haskell's discipline, wrapping (Byte over UInt8) is the right shape, and UInt8-as-itself-Byte (analogous to instancing both `Num Int` and `Monoid Int` on the same underlying type with conflicting laws) is the wrong shape.

#### 2.3 Scala 3: given/using and Typeclass-as-Context

Scala 3's `given`/`using` mechanism makes typeclass instances first-class contextual values, separated from the type's nominal identity. A `given byte_operations: Byte_TypeClass[UInt8] = ...` adds byte-typeclass capabilities to UInt8 *at the call site that imports the given*, without changing UInt8's nominal identity. Different scopes can have different given instances; coherence is enforced by the import structure rather than by global uniqueness (Scala does NOT have Rust's orphan rule or Haskell's global coherence — multiple given instances may coexist if their scopes are disjoint).

Scala's approach reframes Q1 as a scoping question: "should the byte-capability be available wherever UInt8 is in scope?" Scala's answer: depends on what's imported in the consumer's scope. Swift does not have this mechanism — Swift's nominal-typing + global-conformance model is closer to Haskell's than to Scala's. The institute's design space therefore inherits Haskell/Rust's all-or-nothing conformance choice (UInt8 either conforms everywhere or nowhere); Scala-style scoped conformance is not available.

#### 2.4 Swift Numeric Protocol Hierarchy

**Verified citation** (https://raw.githubusercontent.com/swiftlang/swift/main/stdlib/public/core/Integers.swift):

```swift
public protocol AdditiveArithmetic: Equatable
public protocol Numeric: AdditiveArithmetic, ExpressibleByIntegerLiteral
public protocol SignedNumeric: Numeric
public protocol BinaryInteger: Hashable, Numeric, CustomStringConvertible, Strideable
public protocol FixedWidthInteger: BinaryInteger, LosslessStringConvertible
```

`UInt8` conforms to `FixedWidthInteger`, transitively to `BinaryInteger`, `Numeric`, `AdditiveArithmetic`, `Equatable`, `Hashable`, `Strideable`, `ExpressibleByIntegerLiteral`, `CustomStringConvertible`, `LosslessStringConvertible`. This is the entire **arithmetic-algebras capability bundle** for unsigned 8-bit integers in the stdlib.

The institute's `Byte.Protocol` carries an *overlapping but distinct* capability bundle: `Sendable, Equatable, Hashable, Comparable, ExpressibleByIntegerLiteral` (plus byte-specific bitwise extensions in `Byte.Protocol+Bitwise.swift`). The overlap with `FixedWidthInteger`'s bundle is on the stdlib basics (`Equatable`, `Hashable`, `Comparable`, `ExpressibleByIntegerLiteral`); the divergence is on arithmetic (`+`, `-`, `*`, `/`) — Byte deliberately does NOT carry arithmetic operations per `Byte.swift`:30 (`Arithmetic: NOT forwarded — '+', '-', '*', '/' are absent by design`).

**The diverging-bundles observation is decisive for Q1.** The Swift stdlib's numeric hierarchy describes UInt8's purpose: it IS an arithmetic integer. Adding `Byte.Protocol` conformance to UInt8 would make every UInt8 simultaneously:
- An arithmetic value (from FixedWidthInteger): supports `+ - * / %`
- A byte-domain value (from Byte.Protocol): supports `& | ^ ~ << >>` plus byte-stream parser ergonomics

The two bundles are coherent in isolation (a byte CAN be bit-shifted; bytes CAN be added) but they encode different domain intent. The stdlib chose arithmetic as UInt8's primary identity; the institute's intent is to keep `Byte` as a separate-nominal-twin so that byte-domain APIs do not surface in arithmetic-typed code (e.g., `let n: UInt8 = 5; n.peek_byte_stream()` would be type-correct under universal conformance, but the call has no meaning — `n` is a count, not a byte stream).

### 3. Contextualization Step ([RES-021])

Per [RES-021]:

> When a prior art survey identifies a pattern that is universally adopted across surveyed systems but absent from the ecosystem, the survey MUST include a "contextualization step" before classifying the absence as a gap: concretely describe what the proposed concept would look like in the ecosystem's type system, and evaluate what it would cost.

**Pattern observed across external systems**: stdlib numeric primitives instance domain-specific typeclasses directly (Haskell's `Word8: Eq, Ord, Show, Num, ...`; Rust's `u8: Add, Sub, BitAnd, ...`; Swift's `UInt8: FixedWidthInteger, ...`). One could read this as "stdlib primitives in surveyed systems conform to every applicable typeclass," and infer that "UInt8 should conform to Byte.Protocol" by analogy.

**The contextualization step rejects this inference for two structural reasons**:

1. **Cross-system analogy mismatch.** Haskell's `Eq Int`, Rust's `Add for u8`, Swift's `UInt8: FixedWidthInteger` are stdlib-defined typeclasses describing *the stdlib's own intent for the primitive*. They are not third-party domain capabilities bolted on. Byte.Protocol is the *institute's* domain capability — analogous to a third-party library defining its own `Byte` typeclass in Haskell. In Haskell, the convention for that case is the `Sum`/`Product` newtype pattern, not direct instance on the underlying type. In Rust, the convention is the newtype pattern explicitly named in the Rust Book. The cross-system analogy actually *opposes* universal conformance of stdlib primitives to third-party domain typeclasses.

2. **Bundle-conflict cost.** Adding `Byte.Protocol` to UInt8 forces every UInt8 in the ecosystem to simultaneously carry the arithmetic-algebras bundle (Numeric / BinaryInteger / FixedWidthInteger) AND the byte-domain bundle (Byte.Protocol's basics + bitwise extensions). The conflict surfaces at three concrete sites:
   - **Operator shadow**: `UInt8`'s stdlib operators (`+ - * /`) coexist with `Byte.Protocol`'s `< == hash`. Byte.Protocol's `<` is a default-impl extension that takes precedence over the stdlib's `Comparable.<` at unconstrained call sites; the institute's lint rules and overload disambiguation can't tell which was intended.
   - **API surface broadening**: a function `<B: Byte.Protocol>(_ b: B) -> X` that the author intended for byte-stream values would accept arbitrary `UInt8` from arithmetic-typed code. The compile-time discrimination that made `Byte` worth extracting (per [byte-primitive-extraction-and-domain-naming.md](./byte-primitive-extraction-and-domain-naming.md) §"Context") is dissolved.
   - **Carrier-protocol composition**: `Tagged<Tag, UInt8>` would now conform to `Byte.Protocol` (via the recursive `Tagged: Byte.Protocol where Underlying: Byte.Protocol` extension). Every `Tagged`-wrapped-UInt8 — including `Tagged<Cardinal8Bit, UInt8>` if such existed — becomes Byte-typed. The discriminator that separates byte-domain Taggeds from arithmetic-domain Taggeds is lost.

The pattern is not absent from the ecosystem; the ecosystem has *deliberately chosen* the opposite of the cross-system convention for this specific case. The author intent is documented inline at `Byte.Protocol.swift`:11–14:

> UInt8 itself does NOT conform: UInt8 is the arithmetic-algebras type; Byte is its byte-domain twin. The protocol exists precisely to be the "subset of UInt8-carriers that opt in to byte-domain semantics" — UInt8 is excluded so the lifted bitwise/hex/parser ops don't shadow stdlib's existing UInt8 operators.

This is a deliberate design decision, not a gap. [RES-021]'s contextualization step closes the question: the absence of `UInt8: Byte.Protocol` reflects bundle-coherence, not oversight.

## Design Space

Per [RES-029] (Framing-Challenge for Binding/Membership/Placement Questions), Q1 is a semantic-identity question (is UInt8 IS-A Byte.Protocol-conforming-entity?). The ranking-axis priority is:

| Tier | Axis | Disposition for this question |
|------|------|-------------------------------|
| 1 | Semantic identity | UInt8 is the *arithmetic-algebras carrier*; Byte is the *byte-domain twin*. They are different identities. |
| 2 | Operational behavior of adjacent ecosystem types | `UInt` does NOT conform to `Cardinal.Protocol`; the adjacent-type precedent is unanimous. |
| 3 | Cost / pragmatism / ergonomics | Engaged ONLY if Tiers 1+2 leave multiple options structurally valid. |

Tiers 1 and 2 are dispositive here. The design space is enumerated for completeness:

### Option A — Conform `UInt8: Byte.Protocol`

```swift
extension UInt8: Byte.`Protocol` {}
```

**Shape**: `UInt8` becomes a `Byte.Protocol` conformer alongside `Byte`. Generic `<B: Byte.Protocol>(_ b: B)` accepts `UInt8` directly; `Tagged<Tag, UInt8>` conforms via the recursive extension.

**Pros**:
- No wrapping step at byte-stream entry points: raw `UInt8` from stdlib APIs (`String.utf8`, `Data` byte buffers) feeds directly into `Byte.Protocol`-generic algorithms.
- Eliminates `Byte(rawValue:)` boilerplate at the boundary.

**Cons (structural — Tier 1 axis)**:
- Conflates UInt8's stdlib identity (arithmetic) with Byte's institute identity (byte-domain twin). The two identities are categorically distinct per the bundle-conflict analysis above.
- Surfaces `Byte.Protocol`-typed APIs (bitwise extensions, hex-rendering hooks, parser-input shape) at every UInt8 use site in the ecosystem, including code that uses UInt8 as an arithmetic small-int.
- Operator-shadow risk on `<`, `==`, `hash` between Byte.Protocol default-impl extensions and stdlib FixedWidthInteger defaults.
- Violates the precedent set by Cardinal/Ordinal/Vector — none of which conform their stdlib carriers (`UInt`, `Int`) to the X.Protocol.

### Option B — `Byte.Protocol` Conformers Are Explicit; UInt8 Bridges at the Boundary

```swift
// Current state. UInt8 does NOT conform.
// Bridging:
let byte = Byte(rawByte)     // explicit wrap at byte-stream entry
```

**Shape**: `Byte.Protocol` conformers are limited to institute-owned byte-domain types: `Byte`, future `ASCII.Code`, `Latin1.Byte`, `UTF8.Code_Unit`, RFC-specific byte types, etc. UInt8 is the carrier (via `Carrier.Protocol<UInt8>`), not the conformer. Consumers wrap explicitly at the boundary using `Byte(_: UInt8)`.

**Pros (structural — Tier 1 axis)**:
- Preserves the byte-vs-arithmetic identity separation the byte-extraction arc landed for.
- Matches the Cardinal-/Ordinal-/Vector- precedent exactly (Tier 2 axis: operational consensus across adjacent types is unanimous).
- Compile-time discrimination of byte-domain values from arithmetic-domain values is preserved.
- Operator-shadow risk is eliminated by construction.

**Cons**:
- Adds one wrap call at every byte-stream entry point. Empirically, these are localized: the byte stream is *parsed* once at boundary; downstream consumption is `Byte`-typed. The cost is bounded; the wrap is usually `@inlinable` and elides at optimization.

### Option C — Promote the Pattern; Introduce a Meta-Protocol or Generator Macro

Variants considered:
- **C1**: A meta-protocol `Value.Protocol` or `Carrier.Protocol.WithStdlibBasics` that bundles `Carrier.Protocol + Sendable + Equatable + Hashable + Comparable + ExpressibleByLiteral`; `Byte.Protocol`, `Char.Protocol`, `Codepoint.Protocol` refine it uniformly.
- **C2**: A Swift macro (`@CapabilityMarker(carrier: UInt8, literal: .integer)`) that generates the protocol declaration, self-conformance, Tagged-conformance, and default impls.
- **C3**: A skill rule documenting the recipe with worked examples for both refinement and sibling variants.

**Pros**:
- Compresses the per-domain recipe to a single declaration.
- Standardizes the bundle of stdlib basics across all Group A capability markers.

**Cons** (each variant):
- **C1 is blocked by [IMPL-102]** (Carrier-walkback reflection). A meta-protocol that uniformly refines Carrier+stdlib-basics would require overlapping conditional conformances to express the per-domain conformer sets cleanly. The capability-lift family of docs investigated and produced the verdict: *in-principle expressible, in-Swift incomplete*. The verdict is preserved in [`property-tagged-semantic-roles.md`](../../swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md) §"Categorical asymmetry": Group A admits the super-protocol in principle, but Swift's overlapping-conformance rules force the implementation to be incomplete.
- **C2 (macro)** is technically feasible but produces no information the author doesn't already have. The recipe is ~20 lines per domain (protocol declaration + self-conformance + Tagged-conformance + 5 default impls). Compressing 20 lines into 1 macro call exchanges explicit code for macro magic at a poor ratio. The institute prefers explicit code (per `swift-institute/Skills/code-surface` discipline). A macro would also obscure the sibling-vs-refinement choice gated by §1.2.1's recursion-vs-refinement constraint — a structural decision (does X.Protocol need recursive Tagged conformance?) that should be visible at the protocol declaration site, not buried in macro expansion.
- **C3 (skill rule)** is the right form. The recipe is already discoverable across multiple documents (this doc; protocol-abstraction-for-phantom-typed-wrappers.md; cardinal-protocol-unification-memo.md supersession; property-tagged-semantic-roles.md), but it has no single skill-rule home. Promoting the recipe to a skill rule under `code-surface` or a new `capability-marker` rule family is a documentation-and-discoverability win without the C1/C2 costs.

## Recommendation

Per [RES-022] (Recommendation-Section Framing Heuristic — prioritize structural correctness over diff-size; document exceptions explicitly), the recommendation drives on structural correctness:

### Q1 — UInt8 conformance to Byte.Protocol

**RECOMMEND Option B. UInt8 MUST NOT conform to Byte.Protocol.** Conformance is restricted to institute-owned byte-domain types (Byte, plus future ASCII.Code / Latin1.Byte / UTF8.Code_Unit / etc.); `Tagged<Tag, T: Byte.Protocol>` conforms recursively per the existing pattern; `UInt8` is the underlying carrier (via `Carrier.Protocol<UInt8>`) but is NOT a Byte.Protocol conformer.

Rationale:

1. **Semantic identity (Tier 1)**. UInt8 is the arithmetic-algebras type; Byte is the byte-domain twin. The byte-extraction arc (`byte-primitive-extraction-and-domain-naming.md`) landed the separation deliberately: every consumer needing a byte concept gets `Byte`; every consumer needing arithmetic gets `UInt8`. Conforming UInt8 dissolves the separation.

2. **Adjacent-type consensus (Tier 2)**. `UInt` does NOT conform to `Cardinal.Protocol`; `Int` does not conform to `Affine.Discrete.Vector.Protocol`; `Int` does not conform to `Ordinal.Protocol` (Ordinal carries `UInt`, not `Int`, but the pattern transfers). Across every Group A capability marker in the institute, the stdlib carrier never conforms to the domain protocol. Byte conforming UInt8 would be the first and only exception — an inconsistency without justification.

3. **Bundle-conflict avoidance**. The contextualization step (§3) enumerated the three concrete sites where bundle conflict surfaces: operator shadow, API surface broadening, Carrier-protocol composition with `Tagged<_, UInt8>`. All three are real costs; Option B has no symmetric cost (the explicit wrap at entry points is bounded and elides at optimization).

4. **Author intent preserved**. `Byte.Protocol.swift`:11–14 and `Byte.swift`:6–13 document the intentional separation. Honoring the inline documentation is consistent with the institute's "skills are canonical" + "code-as-documentation" disciplines.

### Q2 — Meta-pattern status

**RECOMMEND**:

**(a) Affirm the per-domain X.Protocol recipe as the canonical pattern.** Future byte-shape value types (Char, Codepoint, Word, Line, …) follow the same recipe with per-domain customization (sibling-vs-refinement choice; stdlib-basics bundle tailored to the domain). The pattern is **manual application of a recipe**, not a meta-protocol or macro.

**(b) Promote the recipe to a skill rule.** Add `[API-NAME-001c] Per-Domain Capability-Marker Protocol` (or a similarly numbered rule, exact placement TBD) under `code-surface` or a new `capability-marker` rule family. The rule cites this document and the precedent set in [`protocol-abstraction-for-phantom-typed-wrappers.md`](./protocol-abstraction-for-phantom-typed-wrappers.md); enumerates the two variants (refinement / sibling); identifies the decision criterion (does X.Protocol need an associated type Carrier lacks? if yes → sibling; if no → refinement); names the negative rule (the stdlib carrier MUST NOT conform).

**(c) Decline meta-protocol (C1) and generator-macro (C2) variants.** C1 is blocked by [IMPL-102]'s Swift overlapping-conformance constraint. C2 buys no information and hides the sibling-vs-refinement judgment. Both add complexity without proportionate benefit.

Rationale:

1. **Manual recipe IS the right shape**. The recipe is ~20 lines per domain and exercises per-domain choices that should be visible at the use site (which stdlib basics to include; sibling vs refinement; what default impls to provide). Compressing the recipe into a macro or meta-protocol would either hide the choices or force a uniform bundle that doesn't fit every domain.

2. **The recipe IS already the meta-pattern**. Promoting to a skill rule makes the recipe explicitly normative for future authors. The discoverability gain is real (currently the recipe is split across protocol-abstraction-for-phantom-typed-wrappers.md, cardinal-protocol-unification-memo.md, property-tagged-semantic-roles.md, Ordinal.Protocol.swift's inline comment, and Byte.Protocol.swift's inline comment); a single rule with cross-references centralizes the canonical form.

3. **Negative rule preserves the bundle-conflict guard**. The skill rule MUST name "stdlib carrier MUST NOT conform to the X.Protocol" as an explicit clause. This protects every future capability-marker author from re-deriving the Q1 question.

## What This Closes / What Remains Open

### Closed

- **Q1 (UInt8 conformance)**: closed by this recommendation. UInt8 MUST NOT conform; Byte.Protocol conformance is restricted to institute byte-domain types + recursive Tagged.
- **Q2 (C1: meta-protocol)**: closed by [IMPL-102] cross-reference. Investigated and rejected; preserved in the property-tagged-semantic-roles.md categorical-asymmetry framing.
- **Q2 (C2: generator macro)**: closed by cost-benefit. Buys nothing; hides per-domain judgment.

### Open (Follow-on)

- **Skill-rule placement and ID assignment** for the manual recipe (recommendation 2(b)). Candidates: `code-surface` (alongside [API-NAME-001a/b]), a new `capability-marker` rule family within `code-surface`, or a new top-level skill. Decision deferred to skill-lifecycle workflow.
- **`Tagged<Tag, T: Byte.Protocol>` recursive conformance**: **landed v1.1.0** alongside the refinement-to-sibling refactor of `Byte.Protocol`. `Tagged+Byte.Protocol.swift` provides the recursive conformance mirroring the Ordinal.Protocol precedent: `extension Tagged: Byte.Protocol where Underlying: Byte.Protocol, Tag: ~Copyable` with `byte: Byte { underlying.byte }`, `@_disfavoredOverload init(_ byte: Byte)`, `typealias Domain = Tag`. See §1.2.1 for the constraint principle that drove the structural change.
- **Future byte-domain types** (ASCII.Code, Latin1.Byte, UTF8.Code_Unit, RFC-specific byte types): each follows the recipe. ASCII.Code is the next likely conformer per the byte-extraction arc's domain-naming framing. No structural changes anticipated.
- **The capability-lift-pattern.md restoration**: the original capability-lift-pattern.md and capability-lift-pattern-academic-foundations.md docs were lost mid-session per [`2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md`](./Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md) Part 9. The R6 framing from property-tagged-semantic-roles.md plus the cross-references in `Ordinal.Protocol.swift`:13–17 preserve the substantive findings; full restoration of the academic-foundations doc is a separate question outside this arc's scope. This document does not block on it.

## What This Does NOT Recommend

- **No change to `Byte.Protocol`'s current shape.** The refinement of `Carrier.Protocol + stdlib basics where Underlying == UInt8` is correct as landed.
- **No introduction of a `Value.Protocol` / `Carrier.Protocol.WithStdlibBasics` meta-protocol.** Blocked by [IMPL-102].
- **No generator macro for the recipe.** Cost/benefit poor.
- **No conformance of `UInt8` to `Byte.Protocol`.** Q1 is decided closed.
- **No retreat from the byte-vs-arithmetic separation.** The byte-extraction arc's design intent is preserved.

## References

### Internal — Authoritative

- [`swift-institute/Research/byte-primitive-extraction-and-domain-naming.md`](./byte-primitive-extraction-and-domain-naming.md) v1.0.1 (DECISION, Tier 2, 2026-05-15) — the predecessor arc; the open question 4.B that this document addresses.
- [`swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md`](./protocol-abstraction-for-phantom-typed-wrappers.md) v1.4.0 (DECISION/IMPLEMENTED, Tier 3, 2026-02-13) — canonical per-type protocol pattern; rejected the unified-protocol alternative.
- [`swift-institute/Research/phantom-typed-value-wrappers-literature-study.md`](./phantom-typed-value-wrappers-literature-study.md) v1.0.0 (RECOMMENDATION, Tier 3 SLR, 2026-02-26) — foundational SLR on phantom-typed wrappers; covers Reynolds, Wadler, Hinze, Cheney-Hinze, Fluet-Pucella, Breitner et al., Kennedy, plus Haskell/Rust/OCaml/TypeScript/Swift comparison.
- [`swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md`](../../swift-primitives/swift-property-primitives/Research/property-tagged-semantic-roles.md) v1.1.0 (RECOMMENDATION, Tier 2, 2026-04-23) — canonical Group A / Group B taxonomy; fibration framing.
- [`swift-institute/Research/cardinal-protocol-unification-memo.md`](./cardinal-protocol-unification-memo.md) (SUPERSEDED 2026-05-04) — live-fire precedent for the Cardinal.Protocol sibling; six-package migration evidence.
- [`swift-institute/Research/Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md`](./Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md) — provenance of [IMPL-102]; capability-lift investigation.

### Source files (verified inline documentation)

- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Protocol.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.Protocol.swift):11–14 — author's intent on UInt8 non-conformance.
- [`swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.swift`](../../swift-primitives/swift-byte-primitives/Sources/Byte%20Primitives/Byte.swift):6–13 — byte-vs-arithmetic identity framing.
- [`swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift`](../../swift-primitives/swift-ordinal-primitives/Sources/Ordinal%20Primitives%20Core/Ordinal.Protocol.swift):1–17 — sibling-to-Carrier rationale + cross-reference to capability-lift-pattern.md R#6.
- `swift-primitives/swift-carrier-primitives/Sources/Carrier Primitives Standard Library Integration/UInt8+Carrier.swift` — confirms `UInt8: Carrier.Protocol` (trivial-self-carrier) as the existing surface that suffices for cross-type generic dispatch without Byte.Protocol conformance.

### External — Verified Primary Sources

- **Rust Book ch10-02, "Implementing a Trait on a Type"**: https://doc.rust-lang.org/book/ch10-02-traits.html — orphan rule statement (verified 2026-05-15).
- **Rust Book ch20-02, "Using the Newtype Pattern to Implement External Traits on External Types"**: https://doc.rust-lang.org/book/ch20-02-advanced-traits.html — newtype pattern + orphan-rule relationship (verified 2026-05-15).
- **Haskell Wiki, "Newtype"**: https://wiki.haskell.org/Newtype — newtype convention for declaring different typeclass instances on the same underlying value (verified 2026-05-15).
- **swiftlang/swift Integers.swift**: https://raw.githubusercontent.com/swiftlang/swift/main/stdlib/public/core/Integers.swift — protocol declarations for AdditiveArithmetic / Numeric / SignedNumeric / BinaryInteger / FixedWidthInteger (verified 2026-05-15).

### Foundational Citations (via Internal SLR)

The following foundational citations are cited transitively through [`phantom-typed-value-wrappers-literature-study.md`](./phantom-typed-value-wrappers-literature-study.md), which has already verified each per [RES-021]/[RES-026]; this document inherits their authority without re-verification:

- Reynolds, J. C. "Types, Abstraction and Parametric Polymorphism." *IFIP 1983*.
- Wadler, P. "Theorems for Free!" *FPCA 1989*.
- Hinze, R. "Fun with Phantom Types." *The Fun of Programming*, 2003.
- Cheney, J. & Hinze, R. "First-Class Phantom Types." Cornell CS TR 2003-1901.
- Fluet, M. & Pucella, R. "Phantom Types and Subtyping." *JFP* 16(6), 2006.
- Breitner, J. et al. "Safe Zero-cost Coercions for Haskell." *ICFP 2014*.
- Kennedy, A. "Types for Units-of-Measure." *POPL 1997 / CEFP 2009*.

### Skill Rules

- `[RES-019]` Step-0 Internal Research Grep — research-process SKILL.md.
- `[RES-020]` Research Tiers — research-process SKILL.md.
- `[RES-021]` Prior Art Survey + contextualization step — research-process SKILL.md.
- `[RES-022]` Recommendation-Section Framing Heuristic — research-process SKILL.md.
- `[RES-029]` Framing-Challenge for Binding/Membership/Placement Questions — research-process SKILL.md.
- `[RES-032]` Research Notes Cite Verified Primary Sources — research-process SKILL.md.
- `[IMPL-102]` (provenance: 2026-04-23 carrier-walkback reflection) Super-Protocol Verifiability Under Swift Overlapping-Conformance Rules — implementation skill (proposed action item from reflection; status of skill-update not verified at this writing).
- `[API-NAME-001]` Nest.Name Pattern — code-surface SKILL.md.
- `[HANDOFF-013]` Prior Research Check for Branching Investigations — handoff SKILL.md.

## Changelog

- **v1.1.0** (2026-05-15) — Byte-specific judgment amendment landing alongside the sibling-form refactor of `Byte.Protocol`. Changes:
  - §1.2 sibling-vs-refinement framing flipped: "Byte → refinement" becomes "Byte → sibling". Added §1.2.1 "Recursion-vs-refinement constraint principle" naming the structural rule (refinement form blocks recursive Tagged conformance because `Tagged<Tag, X>.Underlying == X`, not the bottom-most carrier type).
  - §1.4 source-file precedent excerpt updated to reflect the new Byte.Protocol.swift file header (sibling form).
  - §Recommendations 2(a) sibling-vs-refinement clause sharpened to cite §1.2.1.
  - §Q2 C2 macro rationale updated to reference §1.2.1's structural decision.
  - §"What This Closes / Open" — Tagged-recursive-conformance moved from Open to Landed; the structural sibling-form refactor is part of the same commit set as v1.1.0.

  Verdicts (Q1 No, Q2 manual recipe canonical) unchanged. The Byte-specific judgment flips refinement → sibling; the per-domain manual recipe is still the canonical pattern.

- **v1.0.0** (2026-05-15) — Initial recommendation. Both sub-questions addressed:
  - Q1: UInt8 MUST NOT conform to Byte.Protocol (Option B).
  - Q2: per-domain manual recipe is the canonical pattern; promote to skill rule; decline meta-protocol and generator-macro alternatives.

  Discharges the question deferred by `byte-primitive-extraction-and-domain-naming.md` v1.0.1 §"Open Questions" Open Question 4.B, per the brief in `HANDOFF-byte-protocol-capability-marker.md`.
