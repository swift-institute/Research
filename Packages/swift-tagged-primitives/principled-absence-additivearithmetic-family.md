# Principled Absence — `AdditiveArithmetic` / `Numeric` / `SignedNumeric` / `BinaryInteger` / `BinaryFloatingPoint`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` declares conditional conformances to the entire stdlib arithmetic stack:

- `Tagged: AdditiveArithmetic where Underlying: AdditiveArithmetic`
- `Tagged: Numeric where Underlying: Numeric`
- `Tagged: SignedNumeric where Underlying: SignedNumeric`
- `Tagged: BinaryInteger where Underlying: BinaryInteger`
- `Tagged: BinaryFloatingPoint where Underlying: BinaryFloatingPoint` (and `FloatingPoint`)

Each conformance forwards operators (`+`, `-`, `*`, `/`, `%`, etc.) and arithmetic predicates to the underlying Underlying.

Swift Institute's `swift-tagged-primitives` deliberately removes all of these. The argument is that arithmetic on phantom-typed wrappers must be a **per-domain decision**, not a blanket forwarding from the underlying value:

> _"If `Tagged<Tag, Int>` conforms to `Numeric`, then `Index<Graph> + 5` compiles — `5` resolves to `Index<Graph>(_unchecked: 5)` via the chain, and `+` is forwarded to `Int.+`. The consumer is now doing index arithmetic with a literal that bears no domain meaning. The wrapper was supposed to make this hard."_

Tagged's lack of operator forwarding is documented as a feature in [`Research/_Package-Insights.md`](./_Package-Insights.md) §"Tagged's Lack of Operator Forwarding Is a Feature."

This document treats the entire arithmetic family in one place because:
1. The forward-the-operators rationale is identical across all five protocols.
2. The footgun (silent arithmetic on phantom-typed values) applies to all five.
3. Testing AdditiveArithmetic empirically determines the family's classification — Numeric/SignedNumeric/BinaryInteger/BinaryFloatingPoint extend AdditiveArithmetic and add more requirements; if AdditiveArithmetic is HARD, the others are too. If it's SOFT-but-footgun-y, the others are too.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to the arithmetic protocol family (when `Underlying` does)? If absent by default, what is the legitimate opt-in path, and is the conformance even authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.3 — original removal rationale.
- [`_Package-Insights.md`](./_Package-Insights.md) §"Tagged's Lack of Operator Forwarding Is a Feature" — the in-package design memo establishing operator-non-forwarding as a value, not a gap.
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — establishes that arithmetic conformances + literal conformances combine into the silent-overload-resolution footgun. AdditiveArithmetic's `static var zero` requirement also pulls in literal-init paths in some toolchains.
- `swift-cardinal-primitives/Research/Cardinal Numeric Design.md` (if exists) — per-domain arithmetic for Cardinal counts (which DO support arithmetic semantically).

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: AdditiveArithmetic where Underlying: AdditiveArithmetic {
    public static var zero: Tagged { Tagged(_unchecked: .zero) }
    public static func + (lhs: Tagged, rhs: Tagged) -> Tagged {
        Tagged(_unchecked: lhs.underlying + rhs.underlying)
    }
    public static func - (lhs: Tagged, rhs: Tagged) -> Tagged {
        Tagged(_unchecked: lhs.underlying - rhs.underlying)
    }
}
```

(Plus the Numeric, SignedNumeric, BinaryInteger, BinaryFloatingPoint stack on top.)

**Pros**:
- Drop-in arithmetic for any `Tagged<Tag, Numeric>` value. `tagged * 2`, `tagged + tagged`, `tagged.magnitude`, etc. all work.
- Compatible with stdlib and SwiftUI APIs that constrain on `T: Numeric` etc.

**Cons**:
1. **Domain-blind arithmetic**. A `Tagged<User, Int>` representing a user ID gets `*`, `/`, `+`, `-`, etc. Multiplying user IDs by integers, dividing them, taking magnitude — none of these has meaningful domain semantics. The wrapper makes them syntactically available; the *domain* never authorized them.

2. **Cross-typed-wrapper arithmetic via shared Underlying + phantom Tag erosion**. `Tagged<User, Int> + Tagged<User, Int>` is not a defensible operation domain-wise — adding two user IDs produces something nonsensical, but the wrapper's `+` happily computes `Int + Int` without question. The sum has the same User, so the type-system doesn't catch the misuse.

3. **Compounds with literal conformances** (see [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md)): once Tagged is `AdditiveArithmetic` and literals resolve to `Tagged<Tag, X>`, `tagged * 5`, `tagged - 1`, `Tagged.zero + 10` all work. Each of these compiles to `Int * Int`, `Int - Int`, `Int + Int` — the user is doing raw-Int arithmetic on what they thought was a domain-typed value.

4. **Domains that DO have meaningful arithmetic should author it per-domain**. `Cardinal: AdditiveArithmetic` is correct (counts add to counts). `Index<Element>` should NOT have AdditiveArithmetic blanket — index arithmetic is conditional on the collection layout, not on the underlying value's Numeric capability. The blanket conformance fires for the wrong cases.

### Option B — SLI opt-in

```swift
extension Tagged: AdditiveArithmetic
where Tag: ~Copyable & ~Escapable, Underlying: AdditiveArithmetic & Escapable {
    public static var zero: Tagged { Tagged(_unchecked: .zero) }
    public static func + (lhs: Tagged, rhs: Tagged) -> Tagged { Tagged(_unchecked: lhs.underlying + rhs.underlying) }
    public static func - (lhs: Tagged, rhs: Tagged) -> Tagged { Tagged(_unchecked: lhs.underlying - rhs.underlying) }
}
```

**Pros**:
- Default safety preserved.
- Opt-in for consumers who knowingly want blanket arithmetic.

**Cons**:
- Domain-blind arithmetic cost remains, behind import gate.
- **Once a consumer imports SLI, the package-level granularity means EVERY Tagged in their compilation unit gets arithmetic** — including `Index<Element>`, `UserID`, `OrderID`, anything tagged. The opt-in is too coarse.
- **Compounds with literal conformances**: importing SLI enables literal arithmetic on every Tagged, reactivating the multi-protocol footgun cluster.

### Option C — Hard absence + per-domain arithmetic conformance

```swift
// Domains that have meaningful arithmetic conform per-domain:
extension Cardinal: AdditiveArithmetic { ... }   // counts add to counts; meaningful

// Index types that have arithmetic conform per-domain:
extension Index: Strideable where Tag: ~Copyable { ... }   // approved per swift-index-primitives precedent

// Domains without meaningful arithmetic SIMPLY DON'T CONFORM:
// `UserID` cannot be added to / multiplied — the syntax fails to compile.
```

**Pros**:
- Domain-specific arithmetic where it makes sense (Cardinal, Stride, etc.).
- Domains without arithmetic semantics are syntactically prevented from having arithmetic — the type system enforces the restriction.
- Works with the operator-non-forwarding-is-a-feature framing already published in `_Package-Insights.md`.
- Aligns with primitives-layer ecosystem packages (cardinal-primitives, ordinal-primitives, affine-primitives) that author their per-domain operators.

**Cons**:
- Per-domain author responsibility — the domain decides what arithmetic makes sense, then conforms accordingly.

## Empirical verification

[`Experiments/tagged-no-additivearithmetic-family/`](../Experiments/tagged-no-additivearithmetic-family/) tests Option B's authorability for AdditiveArithmetic on Swift 6.3.1, demonstrates the domain-blind arithmetic footgun, and demonstrates the per-domain alternative.

## Outcome

**[Updated post-experiment]**:

The experiment empirically verified that **Option B (SLI-style opt-in) IS authorable on Swift 6.3.1** — `static func +`, `static func -`, `static var zero` are function-style; the structural `~Escapable` blocker does not fire.

**Soft / Hard classification**: **SOFT structurally / HARD semantically**.

This is the strongest case in the principled-absence catalog where the structural-vs-semantic split is consequential. The conformance compiles; the footgun is empirically demonstrable; the SLI opt-in path produces working code that does the wrong thing semantically. Consumers who import SLI accept that *every* Tagged in their compilation unit becomes arithmeticky, including types whose domains don't authorize arithmetic.

**Recommendation**: **Do NOT include AdditiveArithmetic family in the SLI target**, despite structural authorability. The package-level granularity of the import makes SLI opt-in too coarse — domains that want arithmetic should conform per-domain (Cardinal, Stride, etc.); domains that don't should not be silently swept into arithmetic by an SLI import.

This is the singular case in the SLI-eligibility analysis where structural and semantic verdicts diverge, and the semantic verdict wins.

The experiment also demonstrates the per-domain alternative: a `Cardinal`-like domain authors its own AdditiveArithmetic where the operation is semantically meaningful.

**Forward-compatibility note**: Empirical finding specific to Swift 6.3.1; revalidate on toolchain updates. The semantic argument (domain-blind arithmetic) is toolchain-independent.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.3 (the seed paragraph).
- [`_Package-Insights.md`](./_Package-Insights.md) §"Tagged's Lack of Operator Forwarding Is a Feature".
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — arithmetic + literal conformance footgun cluster.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) AdditiveArithmetic / Numeric / etc. extensions.
