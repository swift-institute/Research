# Property and Tagged: Two Semantic Roles of the Phantom-Type Wrapper

<!--
---
version: 1.1.0
last_updated: 2026-04-23
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to: [swift-property-primitives, swift-tagged-primitives]
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-23): Promoted R6 from Low to Medium priority — the named
  taxonomy preempts recurring "should we unify?" discussions.
  Added §"Categorical asymmetry: Group A admits super-protocol unification;
  Group B does not" connecting to swift-primitives/Research/capability-lift-pattern.md
  and capability-lift-pattern-academic-foundations.md. Added §"Fibration view:
  sealed vs connected fibers" sharpening why the namespace isolation is
  load-bearing (Group B fibers admit no horizontal morphisms; Group A's `retag`
  is the cross-fiber morphism). Cross-references to capability-lift companion
  research added.
- v1.0.0 (2026-04-21): Initial Group A / Group B taxonomy with 6 recommendations.
-->

## Context

The swift-primitives ecosystem ships two structurally isomorphic phantom-type
wrappers in separate packages:

- `Tagged<Tag: ~Copyable, RawValue: ~Copyable>` — `swift-tagged-primitives`.
  Foundation of 83+ typealiases across the ecosystem, including `Index<Element>`,
  `Ordinal`, `Cardinal`, every identity-like value.
- `Property<Tag, Base: ~Copyable>` — `swift-property-primitives`. Five-variant
  family (`Property`, `Typed`, `View`, `View.Read`, `Consuming`) for fluent
  accessor namespaces on container types.

Both are single-field structs wrapping a value of their second generic parameter,
discriminated by a phantom `Tag` first parameter, preserving `~Copyable` through
conditional conformance. Side-by-side:

```swift
@frozen
public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
}

public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline internal var _base: Base
}
extension Property where Base: ~Copyable {
    public var base: Base { _read { yield _base } _modify { yield &_base } }
}
```

The two differ only cosmetically: Tagged exposes `rawValue` as a public stored
field; Property exposes `base` as a coroutine-accessor projection over internal
`_base`. Parameter order is identical (discriminator first, value second) —
Property's inline documentation explicitly states it follows Tagged's convention.

Structurally, they are the same mechanism. Semantically, they are used for
orthogonal purposes:

| | Tagged | Property |
|---|---|---|
| What the tag discriminates | **Domain identity** of the value | **Verb namespace** dispatched via extensions |
| Example | `Index<Graph>` ≠ `Index<Bit>` — different kinds of indices in different domains | `Property<Push, Stack>` vs `Property<Pop, Stack>` — same stack, different verb |
| Tag values typical | Existing domain types (`Graph`, `Bit`, `UserID`) | Empty enums defined per-container (`enum Push {}`) |
| Meaningful ops on tag | `retag<NewTag>` (phantom coercion is meaningful) | None — retagging `Push` to `Pop` would be semantically nonsensical |
| Meaningful ops on value | Generic `map`, equality, ordering, arithmetic (lifted) | CoW mutation, pointer projection, borrow/consume |
| Extension surface | Per-domain API (`extension Tagged where Tag == Ordinal { ... }`) | Per-verb API (`extension Property where Tag == Stack<E>.Push { mutating func back(...) }`) |

The trigger for this research: during the 0.1.0 release polish of
swift-property-primitives, a naming-and-architecture review asked whether the
two types should be merged, composed, or unified into a single primitive. The
in-session discussion converged on keeping them as separate nominal types
because extension-namespace isolation is load-bearing: verb-namespace
extensions on `Property<Push, Stack>` would bleed into Tagged's extension space
if the two types were collapsed. But the question of whether that intuition is
grounded in prior art — whether the academic literature names this semantic
distinction, or whether it's a blind spot in the theoretical framing — was left
open.

This document investigates that question.

## Question

Does the academic literature on phantom types name, formalize, or distinguish
the two uses observed in swift-primitives — "phantom tag as domain identity"
(Tagged) vs "phantom tag as verb namespace dispatcher" (Property)? If yes, do
Tagged and Property align with established terminology? If no, is coining new
terms justified, and what is the design recommendation for the ecosystem?

## Analysis

### Scope of prior art

The foundational phantom-type literature is already surveyed in detail by
`swift-institute/Research/phantom-typed-value-wrappers-literature-study.md`
(Tier 3 SLR, 36 papers, 2026-02-26, status RECOMMENDATION). That study covers
parametricity (Reynolds 1983, Wadler 1989), phantom types as a general pattern
(Leijen & Meijer 1999, Hinze 2003, Cheney & Hinze 2003, Fluet & Pucella 2006),
coercibility and roles (Breitner et al. 2014), substructural types (Wadler 1990,
Tov & Pucella 2011), and cross-language comparison (Haskell, Rust, OCaml,
TypeScript, Swift).

This document does NOT duplicate that survey. Instead, it re-reads the same
corpus — plus targeted adjacent sources — through one specific lens: the
**semantic role of the phantom tag**. The SLR treats "phantom type" as a single
category distinguished by *role in the role system* (phantom / representational
/ nominal per Breitner et al.) and *substructural classification* (unrestricted /
affine). Neither of those axes captures the Tagged-vs-Property distinction —
both types are phantom-role on Tag and representational-role on RawValue/Base;
both support affine typing. The SLR's framing is orthogonal to the question here.

### Survey of semantic-role taxonomy

I re-read the SLR's 36 papers and targeted adjacent sources (typestate, lenses,
capability-based security) to identify what each paper's use of phantom types
discriminates. The following groups emerge:

#### Group A — Domain identity

The phantom tag represents the ontological domain of the wrapped value. Different
tags mean different kinds of thing.

- **Kennedy (1997, 2010) — Units of Measure.** `float<meter>` vs `float<foot>`
  are different kinds of measurement. The tag is the physical domain. Arithmetic
  is domain-preserving; cross-domain operations are type errors. This is the
  canonical motivation for phantom-typed numeric wrappers (the Mars Climate
  Orbiter incident).
- **Leijen & Meijer (1999) — DSL Embedded Compilers.** The phantom parameter
  encodes which DSL term category a value belongs to (expression / statement /
  pattern). A `Term<Expr>` is not a `Term<Stmt>`.
- **Kiselyov & Shan (2006) — Lightweight Static Capabilities.** The phantom tag
  is a region/scope identifier — a `Handle<Region>` proves it belongs to
  `Region`. Cross-region operations are rejected.
- **Point-Free `swift-tagged` (2018).** Stated purpose: "phantom types for
  type-safe wrappers" over identity-like values (UserID, OrderID, etc.). The tag
  is the identity domain.
- **Swift Institute `Tagged` (2024+).** `Index<Element>`, `Ordinal`, `Cardinal`,
  `Tagged<CPU, UInt32>` — in each case the tag names the domain of the value.

**Structural signature of Group A**:
- `retag<NewTag>(_:)` is semantically meaningful (move from one domain to another,
  explicit). In Haskell's `Coercible` it's the zero-cost coercion `coerce`.
- `map` is meaningful (transform the value while preserving domain identity).
- Cross-domain operations are type errors, caught at compile time.
- Conditional conformances (Equatable, Hashable, Comparable, Codable,
  BitwiseCopyable, Sendable) lift cleanly from the raw value.
- Typical tag values: pre-existing domain types.

#### Group B — Operation / verb selector

The phantom tag selects which operations apply. Different tags mean the same
wrapped value with different API surfaces.

- **Strom & Yemini (1986) — Typestate.** A value's typestate encodes the
  allowable operations at each point in its lifecycle (open / reading / closed).
  Aldrich et al. (2009) and follow-on typestate work extend this with
  static-typing techniques that are substantially phantom-type-based.
- **Hinze (2003) — Fun with Phantom Types.** The type-safe `printf` example uses
  phantom parameters to thread the format specifier's argument list through the
  type system. The tag represents *what operation sequence the value carries*,
  not a domain identity.
- **Van Laarhoven lenses / profunctor optics** (Pickering et al. 2017, "Profunctor
  Optics: Modular Data Accessors"). Each lens is a value with a phantom-typed
  focus selector. `Lens<Whole, Part>` names an ACCESS PATH — the tag parameter
  (effectively the composition of focus types) selects which accessor applies.
  Not classical phantom types, but occupy the same design space: phantom-typed
  first-class accessors.
- **Kiselyov et al. — Effect handlers with type-indexed operations.** The
  phantom row-type encodes which effects are in scope. Operations are selected
  by which labels the row mentions.
- **Swift Institute `Property<Tag, Base>` (2026).** The tag is an empty enum
  nested on the container; the Property exists to host verb-specific extensions
  (`extension Property where Tag == Stack<E>.Push { mutating func back(_:) }`).
  Call sites read `stack.push.back(x)` — `push` is the verb namespace; `back` is
  the specific operation.

**Structural signature of Group B**:
- `retag<NewTag>(_:)` is semantically *nonsensical* — converting a Push Property
  to a Pop Property would silently rebrand the value under a different verb
  namespace, almost certainly wrong.
- `map` is sometimes meaningful (transform the wrapped container, keep the verb
  namespace), sometimes not (if the transform changes the base type, the
  extension-surface binding breaks).
- Operations are defined by per-tag extensions, not by generic conformances. A
  Property<Push, Stack> gains `.back(...)` via `extension Property where Tag ==
  Stack<E>.Push`; generic Property<T, U> has only the base storage projection.
- Typical tag values: purpose-built empty enums (`enum Push {}`, `enum Peek {}`).
  These are not domain types in their own right — they are pure discriminators.

#### Group C — Capability / permission

The phantom tag represents an authorization or capability token. Adjacent to
Group A but distinct: the tag's presence *permits* the operation, rather than
naming what the value *is*.

- **Launchbury & Peyton Jones (1994) — Lazy Functional State Threads.** The
  phantom `s` parameter in `ST s a` is a state-thread identifier that prevents
  references from escaping their ST computation. Historically the most
  influential capability-style use of phantom types.
- **Kiselyov & Shan (2006) — Lightweight Static Capabilities.** (Appears in both
  Group A and Group C — the paper uses phantom types for both domain identity
  and capability enforcement.)
- **Rust's lifetime parameters** (distinct from `PhantomData`). Lifetimes are
  type-level capability tokens, although Rust's lifetime system extends far
  beyond pure phantom typing.

Group C is tangential to the Tagged/Property distinction — neither primitive is
primarily a capability-token pattern. Noted for completeness.

### Is the Group A / Group B distinction named in the literature?

**Short answer: no, not as a taxonomic distinction within phantom-type
literature.**

The SLR's 36 papers either:
- Use phantom types exclusively for domain identity (Kennedy, Point-Free,
  most industrial uses). The operation-selector role does not come up because
  the paper is focused on identity.
- Use phantom types for multiple purposes without naming the distinction
  (Hinze 2003, Kiselyov & Shan 2006). A single paper mixes identity uses and
  operation-selector uses, treating them all as "phantom type applications."
- Discuss the *mechanism* (roles, parametricity, variance, coercibility)
  independent of what the phantom parameter semantically represents.

**Typestate literature** (Strom & Yemini 1986, Aldrich et al. 2009, DeLine &
Fähndrich 2004) does distinguish *state-tracking* as a distinct use — but
typestate research treats itself as a complement to types, not as a sub-category
of phantom-type use. The framing is "typestate vs type," not "phantom-as-state
vs phantom-as-domain."

**Lens literature** (Foster et al. 2007, Pickering et al. 2017) is framed as
"first-class accessors" or "bidirectional programming" — not as "phantom-typed
wrappers with verb-namespace tags." The kinship to Property is structural but
unnamed in the lens vocabulary.

**The closest named distinction in prior art** is Haskell's **role system**
(Breitner et al. 2014): each type parameter has a role (nominal, representational,
or phantom) that governs what coercions are sound. But roles describe
*coercibility*, not *semantic purpose*. Both Tagged's `Tag` and Property's `Tag`
have phantom role — they are indistinguishable in the Breitner et al. framework.
The semantic-role-of-the-tag distinction is orthogonal to the role system.

I conclude that the distinction the swift-primitives ecosystem has surfaced
(Tagged for domain identity, Property for verb namespace) is **a genuine
taxonomic axis that the phantom-type literature has not named** — not because
it doesn't exist in practice (Groups A and B above show it clearly does), but
because the literature's attention has been on the *mechanism* of phantom types
rather than their *role semantics*.

### Contextualization step ([RES-021])

A prior-art survey that finds "absent from the ecosystem's taxonomy but present
in practice across surveyed systems" must distinguish *genuine gap* from
*deliberate design decision*. Per [RES-021], apply the contextualization step.

**If the distinction were named and adopted — what would the ecosystem look
like?**

Option 1: A single `PhantomTagged<Tag, Value, Role: PhantomRole>` primitive with
a role parameter (Role ∈ {DomainIdentity, VerbNamespace, Capability}).
Consumers pick the role at instantiation. Extensions dispatch on role.

```swift
// Hypothetical unified primitive
public struct PhantomTagged<Tag, Value, Role: PhantomRole>: ~Copyable { … }

// Tagged becomes:
public typealias Tagged<Tag, RawValue> = PhantomTagged<Tag, RawValue, DomainIdentity>

// Property becomes:
public typealias Property<Tag, Base> = PhantomTagged<Tag, Base, VerbNamespace>
```

This would preserve the semantic distinction (different Role → different APIs)
while deduplicating the struct definition. But the extension surface problem
remains: consumers of `Tagged<Stack<E>.Push, Stack<E>>` (if someone wrote that)
would still get the verb-namespace extensions bleeding in, because the
extension-namespace is keyed on `PhantomTagged<_, _, DomainIdentity>` vs
`PhantomTagged<_, _, VerbNamespace>` — and Swift's extension system cannot
constrain extensions on arbitrary type parameters to values of a phantom-role
type parameter. Role would need to be a stored `enum` or a marker protocol,
losing the zero-cost guarantee.

Option 2: Keep separate nominal types (current state), but document the kinship
in the research corpus (this document). Each type's extension surface is
hermetic. Cost: two struct definitions in the codebase that look structurally
identical.

Option 3: Build Property on top of Tagged via composition. Property's top-level
struct holds a `Tagged<Tag, Base>` field. The variants (`Property.View`,
`.View.Read`, `.Consuming`) do not compose the same way because their storage
differs (pointer vs state class).

```swift
// Hypothetical
public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline internal var _tagged: Tagged<Tag, Base>
    public var base: Base {
        _read { yield _tagged.rawValue }
        _modify { yield &_tagged.rawValue }
    }
}
```

**Per the contextualization step, Option 1's unification is technically
possible but semantically lossy.** The extension-namespace isolation is the
entire point of keeping the types separate. Unification either (a) re-creates
the problem by having all phantom-tagged values share one extension surface, or
(b) forces Role into runtime representation, sacrificing zero-cost. Option 3's
composition deduplicates one of five Property variants at the cost of one extra
field-access layer and a cross-package dependency; the other four variants
(View, View.Read, View.Typed, Consuming) retain their own storage and cannot be
expressed in terms of Tagged.

### Theoretical grounding ([RES-022])

The distinction between Group A (domain identity) and Group B (verb namespace)
maps onto a principled theoretical divide that is present in the literature,
even if not named in phantom-type surveys:

| | Group A (domain identity) | Group B (verb namespace) |
|---|---|---|
| Theoretical frame | Nominal typing applied at the type-parameter level | Type-indexed dispatch / instance resolution |
| Canonical operation | `retag: Tagged<A, V> → Tagged<B, V>` (phantom coercion) | `extension Property where Tag == T { … }` (instance-per-tag extensions) |
| Coercibility | Free (zero-cost, `Coercible` in Haskell) | Not meaningful — each tag has its own API |
| Functor structure | `map: (V → W) → Tagged<T, V> → Tagged<T, W>` is principal | Map on the wrapped value often breaks extension bindings |
| Categorical frame | Kleisli-like: Tagged<T, _> is a strong functor in V | Per-tag extension records: a family of algebras keyed by T |

Group A is about giving values *identity* — they remain the same operationally,
just refined. Group B is about giving values *operations* — the wrapped content
can be anything, the tag says what you can do with it.

This corresponds closely to the distinction between **nominal typing** (values
of nominally-distinct-but-structurally-identical types are different kinds of
thing) and **typeclass / ad-hoc polymorphism** (values of a single type acquire
operations per an instance-selection mechanism). In Haskell:

- Group A ≈ `newtype UserID = UserID Int` — nominal distinction.
- Group B ≈ typeclasses with phantom-type-indexed instances. Not a canonical
  Haskell idiom because Haskell does not have local-type-based dispatch of the
  kind Swift's extensions provide.

Swift's combination of nominal typing AND extension-based dispatch per
constrained generic parameters creates a design space where BOTH uses are
first-class and distinct. The ecosystem's emergence of Tagged and Property as
separate primitives reflects this — each addresses one of the two uses cleanly,
without contamination.

### Categorical asymmetry: Group A admits super-protocol unification; Group B does not

Companion research (`swift-primitives/Research/capability-lift-pattern.md`,
`capability-lift-pattern-academic-foundations.md`) probed whether Group A
admits a super-protocol unifying its members (Tagged, Cardinal, Ordinal,
Hash). The investigation produced a partial finding worth surfacing here:
**Group A admits a super-protocol *in principle* (the abstraction is
coherent), but Swift's expressiveness limits make a clean implementation
incomplete.** The deeper observation — relevant to THIS document's
taxonomy — is that **Group B does not admit a super-protocol at all**,
and the categorical reason for that asymmetry sharpens R1.

**Why Group A admits unification (in principle)**: every Group A member
shares a uniform meaning across instances. `Tagged<Bytes, Cardinal>`,
`Tagged<Frames, Cardinal>`, and bare `Cardinal` all participate in the
same "Cardinal-carrying" abstraction. A protocol like
`Carrier<Underlying>` (with `Underlying = Cardinal` for Cardinal-shaped
carriers) captures this uniformity. The Tag indexes a *global*
discriminator space — Bytes and Frames are types with meaning across
the ecosystem.

**Why Group B does not admit unification**: Property's Tags are *local*
to each container. `Stack.Push` and `Deque.Push` are not the same Push;
they're independent empty enums that happen to share a name. There is
no global "Push abstraction" that Property unifies. Each Property
extension is keyed on a `(Container, Tag)` pair where the Tag has
meaning only within that Container's namespace.

This asymmetry maps onto categorical structure. The family
`{Property<Tag, Base>}_{Tag, Base}` is a *fibration* over the category
of (Container, Verb) pairs whose fibers have no morphisms between them
— each verb namespace is sealed. By contrast,
`{Tagged<Tag, V>}_{Tag}` for fixed V is a fibration over the category
of Tags whose fibers are connected by the `retag<NewTag>` morphism.
Group A admits cross-fiber morphisms; Group B does not.

**Implication for unification**: a hypothetical super-protocol would
need to abstract over the Tag dimension uniformly. For Group A, this
is meaningful — `some Carrier<Cardinal>` ranges over the Tag-indexed
fiber. For Group B, this is incoherent — there is no uniform meaning
to abstract over (Stack.Push and Deque.Push aren't substitutable). A
super-protocol like `VerbNamespace.\`Protocol\`` would have nothing to
say.

This is the categorical reason R1 is "Critical." The namespace
isolation isn't a convention to be defended — it's a property of
Group B's fibration structure. Group A admits cross-fiber operations
because its fibers are connected; Group B's fibers are sealed by
construction. Lumping them under one type would force Group B's "no
cross-fiber morphisms" property to be re-established by convention
rather than guaranteed by structure.

### Fibration view: sealed vs connected fibers

The vocabulary from `capability-lift-pattern-academic-foundations.md`
§5.2 (vertical / horizontal morphisms over a fibration) gives a
precise frame for the Tagged ↔ Property distinction:

| | Group A (Tagged family) | Group B (Property family) |
|---|---|---|
| Family | `{Tagged<Tag, V> : Tag}` indexed by Tag | `{Property<Tag, Base> : Tag}` indexed by Tag |
| Vertical morphisms (fiber-preserving) | Tag-preserving operations: `Cardinal + Cardinal`, `align(_:)` returns same Tag | Within-namespace operations: `stack.push.back(_:)` |
| Horizontal morphisms (cross-fiber) | `retag<NewTag>(_:)` — explicit phantom coercion | **Don't exist** — Push and Pop fibers are sealed |
| Fiber connectedness | Connected (retag bridges fibers) | Sealed (no Property cross-namespace conversion) |

The doc's existing observation that "retagging Push to Pop would be
semantically nonsensical" restates this: **Group B fibers are sealed
by construction**. There is no morphism from `Property<Push, Stack>`
to `Property<Pop, Stack>` — and shouldn't be. Push and Pop are
independent verbs over the same container; bridging them would
silently rebrand an operation under a different namespace.

This sharpens R1's priority from "convention argument" to
"structural argument": separate types preserve sealed fibers by
type identity. A unified type with phantom Role would force the
sealed-fiber property to hold by extension hygiene rather than by
the type system — exactly the failure mode Swift's overlap-rules
can't prevent.

### Empirical validation ([RES-025])

Applying the Cognitive Dimensions Framework to the question "should the two
primitives be unified?":

| Dimension | Unify (Option 1 above) | Keep separate (current) |
|---|---|---|
| **Visibility** | One primitive; Role parameter visible but can be misread or defaulted | Two primitives, each with clear purpose at the use site (`Tagged<Graph, Int>` vs `Property<Push, Stack>`) |
| **Consistency** | One struct definition; apparent consistency | Separate types that happen to share structure — local consistency within each type |
| **Viscosity** (ease of change) | Higher — changing Role semantics affects all use sites | Lower — changes to verb-namespace Property don't impact Tagged consumers |
| **Role-expressiveness** | Lower — the name `PhantomTagged` does not signal which role a site uses | Higher — `Tagged<Graph, Int>` signals identity; `Property<Push, Stack>` signals verb namespace |
| **Error-proneness** | Extensions on `PhantomTagged<_, _, VerbNamespace>` still bleed across all Tagged-with-that-tag sites | Extensions on `Property<Push, Stack>` are isolated; Tagged consumers are unaffected |
| **Abstraction level** | One abstraction with an added Role axis | Two co-abstractions at the same level, each fully specified |

The separate-types choice scores better on four of six dimensions (visibility,
role-expressiveness, error-proneness, viscosity). Unification scores marginally
on consistency and abstraction-level but at the cost of role-expressiveness and
error-proneness — the two dimensions that most directly affect consumer
correctness.

## Outcome

**Status**: RECOMMENDATION.

### Key findings

1. **The Group A / Group B distinction is real and principled** — it corresponds
   to the theoretical split between nominal-typing phantom uses and
   type-indexed-dispatch phantom uses. The literature has not named this
   distinction as a first-class taxonomic axis within phantom-type research, but
   its instances are present across the surveyed papers.

2. **The ecosystem's two primitives align cleanly with the two roles**. Tagged
   is a Group A (domain identity) phantom wrapper. Property is a Group B (verb
   namespace) phantom wrapper. Parameter-order convention (`Tagged<Tag, RawValue>`
   → `Property<Tag, Base>`) signals the kinship and is appropriate.

3. **Unifying them into a single primitive is technically possible but
   semantically lossy**. The contextualization step ([RES-021]) shows that
   unification either (a) re-creates the extension-namespace pollution problem,
   or (b) forces the role distinction into runtime representation, sacrificing
   zero-cost.

4. **Composing Property on top of Tagged deduplicates one of five variants**.
   The four non-owned Property variants (`View`, `View.Read`, `View.Typed`,
   `Consuming`) have distinct storage shapes that cannot be expressed in terms
   of Tagged. The gain is marginal; the cost (cross-package dependency, extra
   field-access layer) is non-trivial.

5. **The naming in the ecosystem correctly reflects the semantic distinction**.
   `Tagged` names the identity mechanism (the tag identifies the value's
   domain). `Property` names the usage pattern (the wrapper appears as a
   property of the host type, with verb-specific extensions). Neither name is
   misleading; both are appropriate for their group.

### Recommendations

| # | Recommendation | Priority | Rationale |
|---|---------------|----------|-----------|
| R1 | Keep Tagged and Property as separate nominal types | **Critical** | Extension-namespace isolation is load-bearing for the Group A vs Group B semantic separation |
| R2 | Document the kinship in each type's DocC article | **High** | Readers will spot the structural similarity and ask the question this document answers; point them here |
| R3 | Preserve the parameter-order convention (discriminator first, value second) across both | **High** | Signals the kinship at every use site; already in place |
| R4 | Do NOT compose Property on Tagged | **Medium** | Deduplication gain is one-fifth of the Property surface; cost is a cross-package dependency and a field-access layer |
| R5 | Do NOT introduce a unifying `PhantomTagged<Tag, Value, Role>` primitive | **Medium** | Either re-creates the extension-namespace problem (if Role is compile-time only) or sacrifices zero-cost (if Role is runtime) |
| R6 | Coin the terms "domain-identity phantom wrapper" (Group A) and "verb-namespace phantom wrapper" (Group B) in ecosystem documentation | **Medium** *(promoted from Low in v1.1.0)* | Gives future contributors a named vocabulary for the distinction; the literature has not done so. Empirically, "should we unify?" recurs in design discussions — naming the taxonomy preempts re-derivation. The capability-lift research investigation that produced this v1.1.0 update is a worked example of the cost of NOT having shipped vocabulary. |

### What this does NOT recommend

- **No API change to either Tagged or Property.** Both designs are validated by
  this analysis.
- **No merging, composition, or renaming** of either primitive.
- **No introduction of a Role type parameter.** The attempted unification does
  not improve the design.

### Cross-reference from Property and Tagged

The DocC catalogues for `Property Primitives Core.docc/Property.md` and the
`Tagged Primitives.docc` equivalent for Tagged SHOULD add a "Related Work"
section pointing at this document, so readers who spot the structural
similarity (as the user prompting this research did) find the answer without
having to ask.

### Implementation status (2026-04-24)

As of the pre-0.1.0 integration arc completed on 2026-04-24, Property.View and
Property.View.Read on swift-property-primitives main store their base reference
via Tagged:

```swift
Property.View<Tag, Base>      // internal storage: Tagged<Tag, Ownership.Inout<Base>>
Property.View.Read<Tag, Base> // internal storage: Tagged<Tag, Ownership.Borrow<Base>>
```

This usage honors the recommendations above:

- **R1 (separate nominal types)**: respected. `Property.View` is its own nominal
  struct; it is not a typealias for Tagged. The Tagged value is an internal
  storage detail, not the public identity of Property.View.
- **R4 (do not compose Property on Tagged)**: not violated in the sense R4
  warns against. R4 targets a unifying composition where Property *becomes* a
  kind of Tagged; the implementation keeps Property semantically distinct
  (verb-namespace role, Group B) while using Tagged as a phantom-type carrier
  for the domain tag alongside the Ownership-typed base reference. The
  dependency cost R4 cites (cross-package dep on swift-tagged-primitives) is
  accepted in exchange for the namespacing guarantees Tagged provides for the
  Tag phantom.
- **R5 (no Role parameter)**: respected. No `PhantomTagged<Tag, Value, Role>`
  unification was introduced.

Reference: swift-property-primitives commit `a597340` (Property.View*
integration restored to main).

### Follow-on items

- **Short blog post candidate**: "Two kinds of phantom types: domain identity
  vs verb namespace." The distinction is novel enough — per the survey above,
  unnamed in the phantom-type literature — that publishing it as a Swift
  Institute blog post could be of community interest. Tracking this in the
  Blog/ corpus; not part of this research's scope.
- **Monitor Swift Evolution**: if a future `newtype` or role proposal lands, the
  recommendation to keep Tagged and Property separate should be revisited — a
  language-level newtype might enable composition without the extension
  pollution.

## References

### Phantom-type foundations (via SLR)

- Reynolds, J. C. "Types, Abstraction and Parametric Polymorphism." *IFIP 1983*.
- Wadler, P. "Theorems for Free!" *FPCA 1989*, pp. 347–359.
- Leijen, D. & Meijer, E. "Domain Specific Embedded Compilers." *DSL 1999*.
- Hinze, R. "Fun with Phantom Types." In *The Fun of Programming*, 2003.
- Cheney, J. & Hinze, R. "First-Class Phantom Types." Cornell CS TR 2003-1901.
- Fluet, M. & Pucella, R. "Phantom Types and Subtyping." *JFP* 16(6), 2006.
- Breitner, J., Eisenberg, R. A., Peyton Jones, S. & Weirich, S. "Safe Zero-cost
  Coercions for Haskell." *ICFP 2014*. Role system.

### Typestate and operation selection

- Strom, R. E. & Yemini, S. "Typestate: A Programming Language Concept for
  Enhancing Software Reliability." *IEEE TSE* 12(1), 1986.
- DeLine, R. & Fähndrich, M. "Typestates for Objects." *ECOOP 2004*, pp. 465–490.
- Aldrich, J., Sunshine, J., Saini, D. & Sparks, Z. "Typestate-Oriented
  Programming." *OOPSLA 2009*, pp. 1015–1022.

### Lenses and first-class accessors

- Foster, J. N., Greenwald, M. B., Moore, J. T., Pierce, B. C. & Schmitt, A.
  "Combinators for Bidirectional Tree Transformations: A Linguistic Approach
  to the View-Update Problem." *ACM TOPLAS* 29(3), 2007.
- Pickering, M., Gibbons, J. & Wu, N. "Profunctor Optics: Modular Data
  Accessors." *The Art, Science, and Engineering of Programming* 1(2), 2017.

### Capability-style phantom uses

- Launchbury, J. & Peyton Jones, S. "Lazy Functional State Threads." *PLDI 1994*,
  pp. 24–35. The `ST s a` phantom-`s` pattern.
- Kiselyov, O. & Shan, C. "Lightweight Static Capabilities." *PLPV 2006*.

### Units of measure (Group A exemplar)

- Kennedy, A. "Relational Parametricity and Units of Measure." *POPL 1997*,
  pp. 442–455.
- Kennedy, A. "Types for Units-of-Measure: Theory and Practice." *CEFP 2009*,
  LNCS 5161, pp. 268–305.

### Swift ecosystem

- Point-Free. swift-tagged. https://github.com/pointfreeco/swift-tagged
- SE-0390: Noncopyable structs and enums.
  https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
- SE-0427: Noncopyable generics.
  https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md

### Internal

- `swift-institute/Research/phantom-typed-value-wrappers-literature-study.md` —
  Tier 3 SLR on phantom-typed wrappers (foundational for this follow-on).
- `swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md`
  — protocol abstraction for operator unification (Tagged's operator-forwarding
  story).
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift` —
  canonical Tagged definition.
- `swift-property-primitives/Sources/Property Primitives Core/Property.swift` —
  canonical Property definition, with parameter-order comment referencing
  Tagged.
- `swift-property-primitives/Research/variant-decomposition-rationale.md` —
  the 5-variant decomposition for Property; cross-cuts this document's
  analysis at the point of "four non-owned Property variants have distinct
  storage shapes."

### Companion research (capability-lift family)

- `swift-primitives/Research/capability-lift-pattern.md` (v1.2.0+,
  RECOMMENDATION, tier 2) — characterizes the recipe shared by Cardinal,
  Ordinal, Hash, etc. (all Group A members); investigates a Carrier
  super-protocol; documents why a separate `swift-carrier-primitives`
  package was rejected.
- `swift-primitives/Research/capability-lift-pattern-academic-foundations.md`
  (v1.1.0+, ANALYSIS, tier 2) — academic survey grounding the recipe in
  type-classes / parametricity / fibration / free-construction
  literature. The fibration vocabulary used in this document's §"Fibration
  view" originates there.
