# Capability-Lift Pattern: Academic Foundations

<!--
---
version: 1.1.0
last_updated: 2026-04-23
status: ANALYSIS
tier: 2
scope: cross-package
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-23): Added §"Structural composition limit" noting the
  recursive Tagged conformance problem that surfaced in
  capability-lift-pattern.md v1.2.0's Carrier-package walk-back. Cross-
  references property-tagged-semantic-roles.md v1.1.0's categorical-
  asymmetry section. Reaffirmed: the academic framing is correct; Swift's
  expressiveness limits force per-type-protocol design.
- v1.0.0 (2026-04-22): Initial academic survey covering eight lenses
  (phantom types, type classes, parametricity, HKT, parameterised monads,
  tagless final, polymorphism taxonomy, first-class phantom types) and
  novel angles (Tagged as free Carrier, fibrations, Σ-types, parametricity
  of Domain).
-->

## Context

`capability-lift-pattern.md` (v1.2.0, RECOMMENDATION) characterizes the
*.\`Protocol\` recipe and probes a `Carrier<Underlying>` super-protocol. It
draws empirical verdicts but only gestures at academic literature.

This companion document supplies the academic grounding: how the pattern
relates to phantom types, type classes, polymorphism taxonomy, free
constructions, parametricity, higher-kinded polymorphism, parameterised
monads, and tagless final encoding.

Per [feedback_verify_cited_sources.md], every citation in this document
has been verified against primary sources.

**Trigger**: [RES-012] Discovery — proactive theoretical grounding.
**Scope**: Cross-package. **Tier**: 2 — supplies prior art [RES-021] and
theoretical grounding [RES-022] for the parent RECOMMENDATION.

## Question

Three sub-questions:

1. What academic frames best explain the pattern?
2. What angles did the original characterization miss?
3. Do any of those implications change the design recommendations?

## Survey

Eight lenses applied. Brief per-lens summaries (full versions in v1.0.0):

### §4.1 Phantom types as a programming idiom
- **Sources**: Leijen & Meijer 1999 (USENIX DSL); Hinze 2003 ("Fun with Phantom Types," The Fun of Programming).
- **Frame**: Tag in `Tagged<Tag, V>` IS a phantom type. Surfacing it as `Domain` in the protocol is one step beyond classical phantom typing — generic dispatch can USE and PRESERVE the phantom.

### §4.2 First-class phantom types / type witnesses
- **Source**: Cheney & Hinze 2003 (Cornell TR2003-1901, "First-Class Phantom Types").
- **Frame**: Cheney & Hinze make phantoms inspectable; capability-lift makes them deliberately non-inspectable. Different points on a tradeoff curve. The non-inspectability is what gives us free theorems (§4.5).

### §4.3 Type classes & ad-hoc polymorphism
- **Source**: Wadler & Blott 1989 (POPL '89, "How to make ad-hoc polymorphism less ad hoc").
- **Frame**: Swift protocols descend from Haskell type classes. `V.\`Protocol\`` is exactly a type class; Tagged conditional conformance is exactly an instance declaration. The pattern inherits 35+ years of literature.

### §4.4 Polymorphism taxonomy
- **Source**: Cardelli & Wegner 1985 (ACM Computing Surveys 17(4)).
- **Frame**: The pattern is hybrid — parametric outside, ad-hoc inside, with parametric Tagged conditional conformance scaling the inside.

### §4.5 Parametricity & free theorems
- **Sources**: Reynolds 1983 (IFIP, "Types, Abstraction and Parametric Polymorphism"); Wadler 1989 (FPCA, "Theorems for free!").
- **Frame**: `Domain: ~Copyable` is load-bearing for parametricity. Phantom preservation is a *free theorem* (Reynolds), not a programmer convention. Relaxing the constraint would break this.

### §4.6 Higher-kinded polymorphism encoding
- **Source**: Yallop & White 2014 (FLOPS, "Lightweight Higher-Kinded Polymorphism").
- **Frame**: SE-0346 (Swift's lightweight HKT) is what makes `Carrier<Underlying>` syntactically clean. Full HKT (Scala-style) is unavailable; SE-0346 is the closest Swift comes.

### §4.7 Parameterised / graded monads
- **Source**: Atkey 2009 (JFP 19(3-4), "Parameterised notions of computation").
- **Frame**: The pattern is a graded structure indexed by `(Domain, Underlying)`. Vertical (Domain-preserving) vs horizontal (Domain-changing) operations are the formal distinction.

### §4.8 Tagless final encoding
- **Source**: Carette, Kiselyov, Shan (JFP, "Finally Tagless, Partially Evaluated").
- **Frame**: Open-extensibility (downstream packages add Tags without touching Cardinal) is a tagless-final virtue.

## Things we hadn't considered

### §5.1 Tagged is the FREE Carrier (universal arrow)

Tagged is the canonical free Carrier in the categorical sense. There's
a forgetful/free adjunction `(Tag, V) ↔ Carrier`; Tagged is the universal
arrow. Bare value types with `Domain = Never` are the unit at a degenerate
point — not a hack, just the trivial case of the construction.

### §5.2 Phantom-type fibration

`{Tagged<T, V>}_T` is a fibration over the category of Tags. Vertical
(Tag-preserving) vs horizontal (Tag-changing) morphisms gives precise
vocabulary for what the design already does informally.

### §5.3 Σ-type / dependent-pair interpretation

Tagged is a degenerate Σ-type with phantom Tag.

### §5.4 `Domain: ~Copyable` is doing parametricity work

Not just ergonomic suppression — parametricity (Reynolds) requires Domain
be uninspectable. Relaxing breaks free theorems.

### §5.5 Forgetful/free adjunction has a design consequence

Any custom non-Tagged Carrier provably factors through Tagged via the
counit. Justifies: must demonstrate value beyond what Tagged provides.

### §5.6 Carrier as graded structure

Atkey's parameterised monads provide a fully-worked design space if
cross-Tag conversions ever become pressing.

### §5.7 Coherence audit needed before Carrier adoption

Overlapping conformances weren't probed by the empirical experiment.
This concern materialized in v1.2.0 of the parent doc as Problem 2 — see
§"Structural composition limit" below.

### §5.8 SE-0346 IS Swift's HKT-lite

The pattern benefits directly from SE-0346.

## Structural composition limit (added v1.1.0)

The §5.7 coherence concern materialized as a structural blocker when
`capability-lift-pattern.md` v1.2.0 walked back the Carrier proposal. The
short version:

**The "Tagged is the FREE Carrier" framing (§5.1) suggests a universal
parametric conformance**:

```swift
extension Tagged: Carrier where RawValue: Copyable, Tag: ~Copyable {
    public typealias Underlying = RawValue
    public typealias Domain = Tag
}
```

This compiles for one level of Tagged-wrapping. **It breaks for nested
Tagged-of-Tagged-of-V**: `Tagged<A, Tagged<B, Cardinal>>.Underlying`
resolves to `Tagged<B, Cardinal>`, not Cardinal. So
`some Carrier<Cardinal>` rejects two-deep tagged values.

The fix would be a recursive conformance:

```swift
extension Tagged: Carrier
where RawValue: Carrier, RawValue.Underlying == Cardinal, Tag: ~Copyable {
    public typealias Underlying = Cardinal
    public typealias Domain = Tag
    public var underlying: Cardinal { rawValue.underlying }
}
```

This **overlaps** with the per-Underlying conformance
`Tagged: Carrier where RawValue == Cardinal`, and Swift forbids
overlapping conditional conformances.

### Why the academic framing still matters

The free-construction view (§5.1) is correct. Tagged IS the canonical
free Carrier in the categorical sense. **Swift's overlap-rules just
prevent us from EXPRESSING the unification cleanly.** The per-type
Cardinal.\`Protocol\` / Ordinal.\`Protocol\` pattern is what fits Swift's
expressiveness — the recursive accessor (`var ordinal: Ordinal { rawValue.ordinal }`
on the recursive Tagged: Ordinal.\`Protocol\` extension) walks the
nesting that the universal Carrier conformance can't.

**Implication**: the academic framing in §§4–5 explains WHY the per-type
pattern is principled (parametricity, free constructions, fibrations)
without claiming Swift can express the universal abstraction.

### Relation to Group A / Group B asymmetry

`swift-property-primitives/Research/property-tagged-semantic-roles.md`
v1.1.0 §"Categorical asymmetry" makes the complementary point: Group A
(domain-identity) admits a super-protocol *in principle*; Group B
(verb-namespace) does not (its tags are local, no global meaning to
abstract over).

Combining both findings:

| Group | Admits super-protocol in principle? | Admits super-protocol in Swift? |
|-------|--------------------------------------|--------------------------------|
| A (domain-identity: Tagged, Cardinal, Ordinal, Hash) | Yes (per Carrier framing in §5.1) | **No** — recursive Tagged conformance can't be expressed (this §) |
| B (verb-namespace: Property, Property.View, ...) | No (per categorical-asymmetry argument) | No |

So both groups end up at "no super-protocol today," for **different
reasons**. Group A's "no" is contingent on Swift's overlap rules; Group
B's "no" is intrinsic. If Swift ever permits ordered overlapping
conformances or specialization, Group A could get its super-protocol;
Group B never can.

## Implications for design

The original v1.0.0 produced 11 supplementary recommendations. v1.1.0
revises:

7. **Use the fibration vocabulary** when discussing Tag-preserving vs
   Tag-changing operations. Adopted in
   property-tagged-semantic-roles.md v1.1.0.

8. **Don't relax `Domain: ~Copyable`** — load-bearing for parametricity.
   Constraint is a theoretical commitment, not preference.

9. ~~If a custom non-Tagged Carrier is proposed, demand justification.~~
   **Revised**: the Carrier abstraction itself is deferred (per parent doc
   v1.2.0). When a use case emerges, then this rule applies.

10. ~~Audit coherence before adding the Carrier super-protocol.~~
    **Revised**: the audit happened (v1.2.0 §"Problem 2") and produced
    "don't add Carrier today." If revisited, the recursive-conformance
    issue is the first thing to resolve.

11. **Track Swift Evolution on HKT extensions and overlapping-instance
    proposals** — both would unlock variants of this pattern.

## References

All citations verified via primary-source web search 2026-04-23.

### Phantom types
- Leijen & Meijer 1999, *"Domain Specific Embedded Compilers"*, USENIX DSL '99.
- Hinze 2003, *"Fun with Phantom Types"*, The Fun of Programming, Palgrave Macmillan, pp. 245–262.
- Cheney & Hinze 2003, *"First-Class Phantom Types"*, Cornell TR2003-1901.

### Type classes & polymorphism
- Wadler & Blott 1989, *"How to make ad-hoc polymorphism less ad hoc"*, POPL '89, pp. 60–76. DOI: 10.1145/75277.75283.
- Cardelli & Wegner 1985, *"On Understanding Types, Data Abstraction, and Polymorphism"*, ACM Computing Surveys 17(4):471–523.

### Parametricity
- Reynolds 1983, *"Types, Abstraction and Parametric Polymorphism"*, IFIP 1983.
- Wadler 1989, *"Theorems for free!"*, FPCA '89. DOI: 10.1145/99370.99404.

### Higher-kinded polymorphism
- Yallop & White 2014, *"Lightweight Higher-Kinded Polymorphism"*, FLOPS 2014. DOI: 10.1007/978-3-319-07151-0_8.

### Parameterised structures
- Atkey 2009, *"Parameterised notions of computation"*, JFP 19(3-4):335–376.

### Tagless final
- Carette, Kiselyov, Shan, *"Finally Tagless, Partially Evaluated"*, JFP, Cambridge University Press. https://okmij.org/ftp/tagless-final/index.html

### Swift Evolution
- SE-0346, *"Lightweight same-type requirements for primary associated types"*. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md

### Companion documents
- `swift-primitives/Research/capability-lift-pattern.md` (v1.2.0+, RECOMMENDATION) — parent characterization.
- `swift-property-primitives/Research/property-tagged-semantic-roles.md` (v1.1.0+, RECOMMENDATION) — Group A / Group B taxonomy with categorical asymmetry argument.
