# Swift Constrained-Extension Nested-Type Lookup Gap

<!--
---
version: 1.0.0
last_updated: 2026-05-02
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

On 2026-05-02 the Wave 3.5-Corrective L3-policy migration adopted *approach
12+13* (`Tagged<L3-Namespace, L2-Type>` typealias + per-layer policy methods
on constrained extensions of `Tagged`) per
`l3-policy-layering-without-spi-2026-05-02-followup.md` § 7. The followup's
§ 9 generalization table extended the pattern uniformly across the
ecosystem — POSIX syscalls, Win32 syscalls, legal architecture
(`Tagged<CaseLaw_Modifications, NRS_78.\`035\`>`), every future spec/policy
boundary.

The pattern carried an unstated assumption: that *same-name nested
typealiases declared in disjoint constrained extensions* of `Tagged`
discriminate at consumer-site lookup by the where-clause. The followup
template names `Error` as the canonical nested error type for each
`(Tag, RawValue)` instantiation:

```swift
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public typealias Error = POSIX.Kernel.File.Stats.Error
}
extension Tagged where Tag == Memory, RawValue == Memory.Ordinal {
    public typealias Error = Memory.OrdinalError
}
// ... same-name `Error` typealiases on every (Tag, RawValue) leg in the ecosystem
```

In production this means every package that wraps an L2 type via
`Tagged<L3-Namespace, L2-Type>` declares its own `Error` typealias on a
constrained extension. The followup's § 7 dispatch instructions
prescribed this shape across the four corrective namespaces (Stats, Open,
Memory.Map, Time) and the § 9 table generalizes it to every
spec/policy boundary in the ecosystem.

The mid-migration probe surfaced that **Swift's nested-type lookup on
constrained extensions of generic types does not consult the where-clause
as a discriminator at name-resolution time**. Two `extension Tagged where
Tag == X, RawValue == Y { typealias E = ... }` declarations on disjoint
instantiations BOTH appear as candidates for `Tagged<concrete, concrete>.E`
lookup at every consumer site, producing an ambiguity error. The migration
agent pivoted to *Path β* (fresh-enum-at-L3 with explicit per-layer error
types) to restore the build.

**Trigger** ([RES-001]): the empirical confirmation refuted the followup
doc's § 7 architectural claim at production scale. The migration is
proceeding on Path β; this cycle maps the language-level prior art so a
future cycle can decide whether to file upstream and how to codify the
workaround.

**Tier** ([RES-020]): 3 — the gap touches Swift's name-resolution model;
the recommendation establishes a long-lived structural rule that future
APIs depend on (no same-name nested typealiases on disjoint constrained
extensions of the same generic type); the cost of error is high (every
ecosystem-wide layered API affected); expected lifetime spans many
releases until Swift's name-lookup discipline changes.

**Companion experiment** ([RES-008]):
`swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/`
(CONFIRMED 2026-05-02, swift 6.3 system default, macOS 26 arm64).

**Adjacent prior research** ([HANDOFF-013], [RES-019]):
- [`nested-protocols-in-generic-types.md`](nested-protocols-in-generic-types.md)
  (DECISION, 2026-02-13, tier 3) — establishes that protocols cannot be
  nested in generic contexts at all; restriction is hard-coded in
  `lib/Sema/TypeCheckDeclPrimary.cpp:3006-3017`.
- [`nested-protocols-literature-study.md`](nested-protocols-literature-study.md)
  (RECOMMENDATION, 2026-02-13, tier 3) — six-language survey for the
  "protocols nested in generic types" question.

**Structural distinction** (this document is not a duplicate of, nor a
successor to, the two adjacent docs):

| Doc | Question | Mechanism |
|---|---|---|
| nested-protocols-in-generic-types | Can a `protocol P` be nested in `Container<T>`? | No — TypeCheckDeclPrimary.cpp blocks it before any name resolution |
| this doc | When two `extension Container where T==X { typealias E = … }` exist on disjoint instantiations, does `Container<concrete>.E` lookup discriminate by where-clause? | No — name resolution gathers all candidates without filtering |

The two adjacent docs cover *whether the protocol nesting itself is
allowed*. This doc covers *whether the (already-allowed) nested-typealias
mechanism discriminates by where-clause at lookup*. Same language-design
property underlies both — Swift's nominal type system + global coherence
model + open extension model creates blind spots in name resolution — but
the mechanisms, remediation paths, and SE-proposal surfaces differ. This
document extends the two adjacent docs by identifying a third
manifestation of the underlying property; it does not supersede them.

**Adjacent constrained-extension hazard research**:
- [`cross-domain-init-overload-resolution-footgun.md`](cross-domain-init-overload-resolution-footgun.md)
  (RECOMMENDATION, 2026-02-11) — implicit-member resolution on Tagged
  inits across disjoint domains.
- [`implicit-member-init-resolution-hazard.md`](implicit-member-init-resolution-hazard.md)
  (DECISION, 2026-03-10, tier 3) — generalized init-overload taxonomy;
  same-domain-not-cross-domain rule. Latent-hazard framing is
  load-bearing for this document.

The init-resolution hazards (`Ordinal(.one)` selecting the wrong overload)
and the constrained-extension nested-type-lookup gap (this document) are
two manifestations of one structural property: **Swift's overload /
lookup resolution gathers candidates from all extensions in scope without
filtering by the where-clause**. The init hazards are about *value-level*
resolution; this gap is about *type-level* resolution. Together they
delineate a coherent set of "constrained-extension overload-resolution
blind spots" that future Swift Evolution work would need to close
together for the language-design property to be principled.

## Question

The L3-policy migration's Wave 3.5-Corrective-Path-β pivot answers the
production migration question. The remaining open questions about
the Swift compiler gap itself:

1. **Is this a known issue upstream?** Has it been articulated in
   swiftlang/swift issues, Swift Forum threads, or compiler-team
   correspondence as a discrete bug, or only as part of broader
   "constrained extensions are buggy" discussion?
2. **Is there an SE proposal in flight or a discussion thread?**
3. **What do peer languages do?** Among Rust, C++, Haskell, and Scala —
   which discriminate nested-type / associated-type lookup by the type
   parameter at the lookup site, and at which compiler phase?
4. **Is there a Swift-side workaround that preserves the Tagged + Carrier
   ergonomics from the followup doc's § 7?** Or is fresh-enum-at-L3 the
   principled answer for the foreseeable future?
5. **Recommendation**: file upstream + at what severity? What ecosystem
   rule should we codify?

## Empirical Confirmation

The companion experiment (`tagged-cross-instantiation-nested-type-ambiguity/`)
is a 4-target SwiftPM package (~80 LOC total):

- **TaggedCore**: `public struct Tagged<Tag, RawValue>`, two tag types
  (`TagA`, `TagB`), two RawValue types (`RawA`, `RawB`), two error types
  (`NestedAError`, `NestedBError`).
- **LegA**:
  ```swift
  extension Tagged where Tag == TagA, RawValue == RawA {
      public typealias Error = NestedAError
  }
  ```
- **LegB**:
  ```swift
  extension Tagged where Tag == TagB, RawValue == RawB {
      public typealias Error = NestedBError
  }
  ```
- **Consumer** (executable target with both LegA and LegB imported):
  ```swift
  let _: Tagged<TagA, RawA>.Error = NestedAError.a
  ```

Verbatim diagnostic (debug build, exit 1, `Outputs/build-debug.txt` lines
14–35):

```
error: ambiguous type name 'Error' in 'Tagged<TagA, RawA>'
  let _: Tagged<TagA, RawA>.Error = NestedAError.a
                            `- error: ambiguous type name 'Error'

note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedAError')   [from LegA]
  extension Tagged where Tag == TagA, RawValue == RawA {
      public typealias Error = NestedAError
                       `- note: found candidate

note: found candidate with type 'Tagged<TagA, RawA>.Error' (aka 'NestedBError')   [from LegB]
  extension Tagged where Tag == TagB, RawValue == RawB {
      public typealias Error = NestedBError
                       `- note: found candidate
```

The diagnostic is striking on close reading: when looking up
`Tagged<TagA, RawA>.Error`, Swift presents LegB's typealias — declared
under `where Tag == TagB, RawValue == RawB` — as a candidate, captioned
`'Tagged<TagA, RawA>.Error' (aka 'NestedBError')`. The candidate is shown
*as if* the where-clause did not exclude it. The where-clause is not
consulted at name-resolution time at all — it would only be consulted
during per-candidate validation, but with two candidates surviving
lookup, the ambiguity error fires before any per-candidate validation
can disqualify one.

The same diagnostic fires symmetrically for `Tagged<TagB, RawB>.Error`,
in `let` annotations, in `throws(...)` clauses, and in `do throws(...)`
catch blocks. All four use sites in the consumer reproduce the bug. The
build fails at the `emit-module` stage of the consumer target (line 12
of build-debug.txt), confirming this is a name-resolution failure, not
an instantiation-time failure.

**Verification status** ([RES-013a]): the diagnostic above is reproduced
verbatim from the experiment's `Outputs/build-debug.txt` on
2026-05-02; the experiment is the single empirical primary source.
[Verified: 2026-05-02]

## Analysis

### A. Swift Compiler Internals — Why the Gap Exists

The Swift compiler's nested-type lookup pipeline gathers candidates first,
then validates per-candidate. The relevant phases (citing
`swiftlang/swift` `main` as of 2026-05-02):

| Phase | File | Function | Behavior |
|---|---|---|---|
| 1 | `lib/AST/NameLookup.cpp` | `DeclContext::lookupQualified` | Pulls every matching `TypeDecl` regardless of the extension's where-clause; constraint-agnostic. |
| 2 | `lib/Sema/TypeCheckNameLookup.cpp` | `TypeChecker::lookupMemberType` | Deduplicates by canonical type. Two distinct typealiases pointing at distinct underlying types (`NestedAError`, `NestedBError`) survive deduplication. |
| 3 | `lib/Sema/TypeCheckType.cpp` | `TypeResolver::applyGenericArguments` → `checkContextualRequirements` | PER-candidate constraint validation — runs once on the resolved type, *not* a multi-candidate disambiguator. |

The architectural shape is **lookup-then-validate**: the compiler gathers
all syntactic candidates, then validates each independently. When two
candidates from disjoint constrained extensions both survive deduplication
(because they resolve to different underlying types), the ambiguity error
fires before any per-candidate validation can disqualify one based on
its where-clause. There is no `lookup_with_constraint_filter` machinery in
the codebase. [Verified: 2026-05-02 via subagent verification against
swiftlang/swift compiler source — see "Swift Compiler Source Citations"
in references]

### B. Swift-Side Prior Art (Verified)

The exact bug-shape under investigation — *"two extensions with disjoint
same-type constraints declaring the same nested name produce an ambiguous
lookup at a base satisfying only one"* — has not been articulated as a
discrete tracked issue in swiftlang/swift. Adjacent issues, all related
to the same lookup-then-validate architectural shape, span eight years of
filed and unfilled work.

#### B.1 Direct Precedent: SR-5440 / GH#48014 (CLOSED)

[`swiftlang/swift#48014`](https://github.com/swiftlang/swift/issues/48014)
(Jens Persson, filed 2017, closed 2020, fixed by PR #28275). Original
reproducer (verbatim):

```swift
struct S<T> {
    var v: (A, B, C)
}
extension S where T == Int {
    typealias A = Int
}
extension S where T == Bool {
    typealias B = Bool
}
extension S where T == Float {
    typealias C = Float
}
print(S<String>.A.self) // Int — incorrectly accepted; T==Int constraint not met
```

This is the **wrong-base** case: `S<String>` does not satisfy any of the
where-clauses, yet all three typealiases were accessible. The bug-class
under investigation (this document) is the **disjoint-overload-with-
matching-base** case: `S<Int>.A` matches LegA's where-clause, *and*
LegB's typealias `A` (declared under `where T == Bool`) also appears as a
candidate, and lookup is ambiguous. PR #28275 added per-candidate
validation (the "validate" step of lookup-then-validate); it did not
change the lookup step's gather-all-candidates behavior. The
disjoint-overload-with-matching-base case remains. [Verified: 2026-05-02
via `gh issue view 48014` and `gh pr view 28275`]

#### B.2 The Closing PR's Own Scope Disclaimer

[`swiftlang/swift#17168`](https://github.com/swiftlang/swift/pull/17168)
(Huon Wilson, MERGED 2018-06-14, "[Sema] More aggressive consideration of
conditionally defined types in expressions") — earlier partial fix for
SR-5440. Description (verbatim from PR body):

> "This should complete the expression-type-checking sides of
> https://bugs.swift.org/browse/SR-5440 and
> https://bugs.swift.org/browse/SR-7976 and rdar://problem/41063870. **We
> don't validate conditionality for decls at all yet.**"
> [Verified: 2026-05-02 via `gh pr view 17168`]

The "we don't validate conditionality for decls at all yet" admission is a
2018 compiler-engineer statement that the gap exists at the
declaration-validation step. PR #28275 (2019) closed the
expression-resolution side for the wrong-base case; the
disjoint-overload-at-matching-base case remained out of scope.

#### B.3 SR-7516 / GH#50058 (OPEN, In Progress, eight years)

[`swiftlang/swift#50058`](https://github.com/swiftlang/swift/issues/50058),
"Compiler accepts ambiguous and/or invalid use of associated types", filed
2018, status OPEN, "In Progress", assignee @AnthonyLatsis. Comments
(verified 2026-05-02 via `gh api repos/swiftlang/swift/issues/50058/comments`):

> "[#30700] Fixes the less source-breaking part, that is, everything except
> for **associated type resolution ambiguities** like these: …"
> — Anthony Latsis, swiftlang/swift contributor

> "I haven't seen a principled fix while working on this, so it is likely
> those now 'working' examples are either just a favorable combination
> of circumstances or the result of some change in validation that makes
> extensions be visited before primary declarations."
> — Anthony Latsis

The "I haven't seen a principled fix" admission is decisive for the
recommendation in this document: a near-term compiler-team fix for the
disjoint-overload-at-matching-base case is unlikely. The bug class this
issue tracks is broader than this document's gap, but the gap is a
specialization of it (associated-type / nested-type resolution
ambiguities at a base satisfying multiple disjoint constraints).

#### B.4 Forum Position: Conditional Type-Member Overloading is "Not Supported"

[`forums.swift.org/t/typealias-in-constrained-extension-should-this-compile/34863`](https://forums.swift.org/t/typealias-in-constrained-extension-should-this-compile/34863)
(2020, principal: Jens Persson; respondent: Anthony Latsis):

> "This one is different. Should have been a redeclaration (we are not
> supposed to support **this kind of conditional type member
> overloading**, not that it's completely senseless to do so)."
> — Anthony Latsis [Verified: 2026-05-02 via WebFetch]

[`forums.swift.org/t/how-to-select-different-associated-type-based-on-type-constraints/17214`](https://forums.swift.org/t/how-to-select-different-associated-type-based-on-type-constraints/17214)
(2018, Latsis):

> "There's something important I've overlooked in your example. One of
> your extensions is unconstrained, meaning a type alias is declared as
> part of the enclosing type's primary declaration. Naturally, a second
> declaration of a type alias with an equal identifier is then considered
> a redeclaration. **Note this isn't an overload, as it would be with
> methods.** I was initially referring to a situation when all relevant
> type alias declarations occur in constrained extensions"
> — Anthony Latsis [Verified: 2026-05-02 via WebFetch]

These two quotes establish the **language-design position** as of the most
recent on-record statement (2020): conditional type-member overloading
(typealiases varying by where-clause on disjoint constrained extensions
of the same generic) is not supported, and there is no public design
work intending to support it. The followup doc's approach 12+13 template
implicitly assumed it WOULD work, but the intended language-design
position is that it doesn't. The empirical bug under investigation is
not a "fix-our-implementation" gap — it is a "this is not how the
language is designed to work" gap. The remediation path is therefore not
"file a Sev1 compiler bug"; it is "either get the design position
changed via SE-proposal, or design the ecosystem around the
language-design position as-is."

#### B.5 SE Proposal Survey

Searched `swiftlang/swift-evolution/proposals/` for "constrained",
"extension", "nested", "where", "lookup". Closest topical:

| Proposal | Status | Relevance |
|---|---|---|
| [SE-0048](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0048-generic-typealias.md) | Implemented | Generic typealiases at top level — does not address constrained-extension nested case. |
| [SE-0142](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0142-associated-types-constraints.md) | Implemented | `where` clauses on associatedtype — does not address lookup discipline. |
| [SE-0143](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0143-conditional-conformances.md) | Implemented | Conditional conformances — adjacent shape; does not address typealias overload at lookup. |
| [SE-0299](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md) | Implemented | Static-member implicit lookup in generic contexts — adjacent for value-level resolution; does not address type-level. |
| [SE-0361](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0361-bound-generic-extensions.md) | Implemented | `extension Array<String>` syntactic sugar — pure renaming, no lookup-discipline change. |
| [SE-0404](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0404-nested-protocols.md) | Implemented | Allows nesting protocols in non-generic contexts — explicit Future Direction notes generic contexts deferred. |

**No accepted or in-flight SE proposal addresses where-clause filtering of
nested-type candidates at name lookup.** [Verified: 2026-05-02 via
swift-evolution proposal index]

#### B.6 Closely Related Open Issues (Indirect Manifestations)

| Issue | Status | Bug class |
|---|---|---|
| [#46458 / SR-3873](https://github.com/swiftlang/swift/issues/46458) | OPEN | Concrete-type extension method resolution differs from protocol extension |
| [#49765 / SR-7217](https://github.com/swiftlang/swift/issues/49765) | OPEN | Protocol composition with conflicting typealiases — no diagnostic |
| [#83564](https://github.com/swiftlang/swift/issues/83564) | OPEN | Synthesized-extension handling of conformance constraints |
| [#87030](https://github.com/swiftlang/swift/issues/87030) | OPEN | IRGen crash: closure with typed throws using nested Error in generic type *(filed by coenttb — author of this ecosystem)* |
| [#87839](https://github.com/swiftlang/swift/issues/87839) | OPEN | Compiler crash on macro applied to nested type in constrained extension on generic type |

The cluster shape — five open issues spanning name lookup, IRGen,
typealiases-in-protocol-composition, conformance-aware extension
synthesis, and macro expansion — confirms that the constrained-extension
nested-type pipeline is a load-bearing-but-undertested area of Swift's
compiler. The open count after eight years of filed work is itself
evidence that this is structurally hard.

### C. Cross-Language Prior Art ([RES-021])

The `nested-protocols-literature-study.md` adjacent doc surveyed six
languages for the *"can a protocol be nested in a generic type"* question.
This document asks the structurally-distinct question *"do specializations
discriminate by where-clause / type parameter at name lookup?"* The
relevant axis is which compiler phase carries the discrimination, and
how soundness is preserved.

#### C.1 Rust — Trait selection picks one impl, no lookup ambiguity

**Mechanism**: trait associated types (`type Item;`) on a trait, defined
per `impl Trait for ConcreteType`. Inherent impls cannot declare
associated types — only methods and constants — so the analog of Swift's
nested typealias on a constrained extension exists only via traits. (See
*"They cannot contain associated type aliases"* in the Reference
*Implementations* page.)

**Discrimination at lookup?** Yes — at *trait selection* (HIR/MIR
projection-normalization). The projection `<Foo<i32> as Trait>::Bar` is
normalized by *first* selecting an `impl` candidate via the trait
solver, then reading `type Bar` off the chosen impl. Disjoint impls
(`impl Trait for Foo<i32>` vs `impl Trait for Foo<u32>`) are coherent
(orphan/overlap rules forbid ambiguity ahead of time), so a *single*
impl wins and projection succeeds. Specialization (RFC 1210, unstable)
refines this with a "most specialized impl known to apply" rule.

**Primary citations**:
- [rustc-dev-guide *Specialization*](https://rustc-dev-guide.rust-lang.org/traits/specialization.html):
  "selection returns *a single impl on success* — this is the most
  specialized impl *known* to apply"
- [`rustc_trait_selection::traits::project`](https://doc.rust-lang.org/nightly/nightly-rustc/rustc_trait_selection/traits/project/index.html):
  "The guts of `normalize`: normalize a specific projection like
  `<T as Trait>::Item`. The result is always a type"
- [Rust Reference *Implementations*](https://doc.rust-lang.org/reference/items/implementations.html):
  inherent impls "cannot contain associated type aliases"

**vs Swift**: Rust avoids Swift's gap because lookup is not name-based
against an extension set — it is a *trait-selection query* that picks
*one* impl from disjoint candidates, then reads the associated type off
that impl. The discrimination is structural (which impl applies?) rather
than syntactic (which extensions match the where-clause?).

#### C.2 C++ — Specializations are unrelated types, picked before lookup

**Mechanism**: class template (full / partial) specialization with nested
type aliases.

**Discrimination at lookup?** Yes — but not via name lookup at all. It
happens during **template specialization selection** *before* any nested-
name lookup occurs. Two-phase name lookup (`[basic.lookup]`) operates on
the *already-selected* specialization's scope.

**Primary citations**:
- [C++23 draft `[temp.expl.spec]/13`](https://timsong-cpp.github.io/cppwp/n4868/temp.expl.spec):
  *"The definition of an explicitly specialized class is unrelated to the
  definition of a generated specialization. That is, its members need not
  have the same names, types, etc. as the members of a generated
  specialization."*
- [C++ draft `[temp.spec.partial.match]`](https://eel.is/c++draft/temp.spec.partial):
  *"If exactly one matching partial specialization is found, the
  instantiation is generated from that partial specialization. … If more
  than one matching partial specialization is found, the partial order
  rules … are used"*
- [C++23 draft `[temp.class.spec]`](https://timsong-cpp.github.io/cppwp/n4868/temp.class.spec):
  *"The members of the class template partial specialization are
  unrelated to the members of the primary template"*

**vs Swift**: in C++, `Foo<int>` and `Foo<float>` are *different types*;
full specializations are quite literally unrelated declarations sharing
only the spelling. There is no "one generic Foo with multiple constrained
extensions" view; there is a primary template plus a bag of
specialization declarations, and the compiler picks one before lookup.
Swift's gap (gathering all candidates without where-clause filtering)
cannot occur because there is no "all candidates" set to gather from at
the nested-name lookup phase.

#### C.3 Haskell — Type-family reduction at solver time

**Mechanism**: open type families + standalone `instance`, closed type
families with built-in equation list, and associated type families on a
class.

**Discrimination at lookup?** Yes — at *type-family reduction*
(constraint solving). Open and associated families select an instance by
*unification + apartness*: an instance applies iff the application
*matches* its LHS and is *apart* from any conflicting instance (overlap
is rejected at instance-declaration time). Closed families try equations
top-to-bottom with the same apartness check ensuring no earlier equation
could ever apply.

**Primary citations**:
- [GHC User's Guide — Type Families](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/type_families.html):
  *"A closed type family's equations are tried in order, from top to
  bottom, when simplifying a type family application"*; *"GHC will select
  an equation only when it is sure that no incompatible previous equation
  will ever apply"*
- [HaskellWiki — GHC/Type families](https://wiki.haskell.org/GHC/Type_families):
  *"[for closed families] equations are tried in order, similar to a
  term-level function definition. … the first matching equation wins"*
- Eisenberg, Vytiniotis, Peyton Jones, Weirich. "Closed Type Families
  with Overlapping Equations." POPL 2014.
  [PDF](https://simon.peytonjones.org/assets/pdfs/closed-type-families.pdf)
  — formalizes the apartness algorithm.

**vs Swift**: Haskell handles the analog cleanly. `Bar Int` and
`Bar Float` reduce to *different* types because reduction is driven by
the *type index*, not the name `Bar`. The discrimination is at solver
time, not at parsing/scope time. Swift's gap — *"lookup gathers all `E`
typealiases across constrained extensions without filtering by where-
clause"* — has no Haskell counterpart because there is no name-based
lookup of the RHS at all; the family head + index is the lookup key.

#### C.4 Scala 3 — Lookup is path-dependent (`memberType` + `asSeenFrom`)

**Mechanism**: type members (`type Bar`) inside traits/classes, accessed
via path-dependent types (`p.Bar` where `p` is a stable path) or `T#Bar`
(Scala 2 type projection; **removed in Scala 3**).

**Discrimination at lookup?** Yes — at type-member resolution
(`memberType` + `asSeenFrom`). The Scala 3 specification operationalizes
this as `memberType(T, id, p)`: locate the member named `id` in `T`,
return its definition *as seen from* the prefix `p`, with this-types and
class type parameters substituted via `asSeenFrom`.

**Primary citations**:
- [Scala 3 Specification — Types §3](https://www.scala-lang.org/files/archive/spec/3.4/03-types.html):
  *"`memberType(T, id, p)` finds a member of a type (`T.id`) and computes
  its underlying type (for a term) or type definition (for a type) as
  seen from the prefix `p`."*; *"[`asSeenFrom`] rebases the type `T` 'as
  seen from' the prefix `p`. Essentially, it substitutes this-types and
  class type parameters in `T` to appropriate types visible from outside."*
- [Scala 3 work-in-progress spec announcement](https://www.scala-lang.org/blog/2023/09/25/work-in-progress-scala-3-specification.html):
  *"everything is turned around. … `p.C` is used for class types
  everywhere"* (re: removal of `T#X` projections)
- Amin, Rompf. "Type Soundness for Dependent Object Types (DOT)."
  OOPSLA 2016.
  [PDF](https://www.cs.purdue.edu/homes/rompf/papers/rompf-oopsla16.pdf)
  — formal foundation underpinning `memberType` / `asSeenFrom`.

**vs Swift**: Scala handles the analog cleanly because **the prefix
value/path determines the scope of nested-type lookup**, not a globally-
gathered set of constrained extensions on the generic type. Two different
subclasses (`FooInt`, `FooFloat`) carry disjoint `type Bar` definitions
in disjoint prefixes; there is no shared lookup namespace. Swift's gap is
closer to the **abandoned Scala-2 `C[T]#Bar` type projection form** —
which is exactly what Scala 3 *removed* for soundness reasons (DOT
metatheory).

#### C.5 Comparison Table

| Language | Discriminates at lookup? | Phase | Mechanism | Has Swift's gap? |
|---|---|---|---|---|
| Rust | Yes | Trait solver / projection normalization | `<T as Trait>::Item` selects *one* impl, then reads its `type Item` | No — coherence + single-impl selection |
| C++ | Yes | Template specialization selection (before name lookup) | Primary + partial + full specializations are *distinct* classes; partial-ordering picks one | No — `Foo<int>` and `Foo<float>` are unrelated types |
| Haskell | Yes | Type-family reduction (constraint solver) | Match + apartness on the type index; first-match for closed families | No — no name-based lookup of nested RHS |
| Scala 3 | Yes | `memberType` + `asSeenFrom` on the prefix path | Path-dependent: `p.Bar` looked up in `p`'s scope, not the parent generic's | No — `T#Bar` projection was removed in Scala 3 |
| Swift | **No** | n/a — lookup gathers all syntactic candidates from extensions in scope, then per-candidate validation | `lookupQualified` is constraint-agnostic; `applyGenericArguments` validates per-resolved-candidate, not as a multi-candidate disambiguator | **Yes — the gap under investigation** |

**Principled answer per language**: All four surveyed languages
discriminate, but **none use Swift's "name lookup over the union of
constrained extensions" approach**. Rust treats it as a solver query
(*which impl?*). C++ treats specializations as unrelated declarations
and picks one before lookup. Haskell treats the family head as a
function on type indices and reduces. Scala 3 ties lookup to a prefix
path, eliminating the "view the nested type through the generic head"
pattern entirely (the Scala-2 projection that allowed it was removed for
DOT soundness reasons).

Swift's gap is therefore *unique* among these four. Each language's
analog is principled because the language refuses to expose lookup as
"gather all syntactic candidates with the same name on the generic type
and reconcile" — a pattern that, in DOT-style metatheory, is known to be
unsound when type members are abstract. The Scala-2 → Scala-3
trajectory is particularly cautionary: Scala had Swift's pattern
(approximately) and abandoned it for soundness.

### D. Theoretical Grounding ([RES-022], [RES-024])

#### D.1 Lookup-then-validate vs Solver-Driven Discrimination

The four surveyed languages share one structural property: discrimination
is *driven by the type-level instantiation*, not by name-based gathering.
Rust's projection normalization, C++'s template specialization selection,
Haskell's type-family reduction, and Scala 3's `memberType`/`asSeenFrom`
all *start* from a type-level commitment (which impl, which
specialization, which family head, which prefix path) and *then* read
the relevant nested name off the committed instantiation.

Swift's lookup-then-validate architecture inverts this: it *starts* from
the name (`Tagged<X, Y>.Error`) and gathers all syntactic candidates
that match the name, then attempts per-candidate validation. The
validation step can disqualify a single candidate (the wrong-base case
fixed by PR #28275), but it has no built-in disambiguator when multiple
candidates survive lookup.

The architectural shape can be modeled as two distinct lookup judgments:

```
─── Solver-driven discrimination (Rust/C++/Haskell/Scala) ───

Γ ⊢ T : Type    Γ ⊢ select_impl(T) ⇒ I    Γ ⊢ I.name = D
─────────────────────────────────────────────────────────────
Γ ⊢ T.name : D


─── Lookup-then-validate (Swift) ───

Γ ⊢ T : Type    Γ ⊢ gather_candidates(name) ⇒ {D₁, …, Dₙ}
Γ ⊢ ∀i. validate(T, Dᵢ) ⇒ accept | reject

if exactly one accept: T.name : Dᵢ
if zero accepts: error "no member named name"
if ≥2 accepts: error "ambiguous type name"
```

The Swift judgment requires the validation step to disqualify all but
one candidate. When two constrained extensions declare the same name on
disjoint instantiations and both candidates survive *gather*, the
*validate* step must independently reject one — but Swift's
`applyGenericArguments` only validates the *resolved* candidate against
the parent type's substitution map; it does not consult the *other*
candidate's where-clause. Both candidates pass per-candidate
validation independently (each is a valid declaration in its own
right), and the ambiguity error fires.

The fix would be either:
1. **Filter at gather time**: extend `lookupQualified` to consult each
   candidate's enclosing extension's where-clause and the parent type's
   substitution map *during gathering*, dropping candidates whose
   where-clauses are unsatisfiable for the parent type. This is the
   "constraint-aware name lookup" path. Swift's current architecture
   does not support this.
2. **Change to solver-driven discrimination**: model nested-type lookup
   as a constraint-solver query that picks *one* extension based on the
   parent type's substitution map, then reads the nested name off it.
   This is structurally what Rust does. Would require redesigning
   Swift's name-resolution architecture.

Both paths are deep changes. The Latsis "I haven't seen a principled
fix" admission (B.3) suggests neither is in flight or intended.

#### D.2 The Soundness Argument — DOT Metatheory

The Scala-2 → Scala-3 trajectory provides the strongest soundness
argument for the lookup-then-validate model's instability. Scala 2
allowed `T#A` type projection — a "view the nested type through the
generic head" pattern that is structurally analogous to Swift's
constrained-extension nested-type lookup. The DOT calculus
(Amin & Rompf, OOPSLA 2016) proved this pattern unsound when the type
members are abstract: the "bad bounds" exploit constructs
`Any => Nothing` functions through abstract type projections, allowing
runtime ClassCastException. Scala 3 dropped general type projections;
projections on *concrete* types remain legal, projections on *abstract*
types are forbidden.

Swift's gap is not directly the bad-bounds exploit (Swift's `where T == X`
clauses pin to concrete types, not abstract ones), but the architectural
shape is the same: gathering candidates by name from a generic head
without solver-driven discrimination. The DOT soundness story does not
prove Swift's lookup is unsound, but it does prove the architectural
shape Swift adopted is the one that historically led to soundness
failures in Scala. Languages that fully adopted solver-driven
discrimination (Rust, Haskell) did not encounter the same soundness
issues; languages that hybridized (Scala 2) had to retreat.

The recommendation in this document does not claim Swift's lookup is
unsound. It claims Swift's lookup is *imprecise* — the where-clause is
not consulted at the gather step — and that this imprecision is a
known property of the lookup-then-validate architecture, not a fixable
bug in a specific call site.

### E. Workaround Analysis (Production Migration Disposition)

The followup doc § 7 enumerated approach 12+13 as the principal-
discovered structural answer. The empirical confirmation (Experiments/
tagged-cross-instantiation-nested-type-ambiguity/) refutes that approach
at production scale when *multiple* per-leg constrained extensions
declare same-name nested typealiases. The followup brief enumerated two
candidate Swift-side workarounds (the "V5+" experiment variants) and
asked whether either preserves Tagged + Carrier ergonomics.

#### E.1 V5 — Drop nested typealiases; route via `Tagged<X, Y>.RawValue.E`

Consumers write `Tagged<POSIX, ISO_9945.Kernel.File.Stats>.RawValue.Error`
to reach the L2 type's nested error.

**Effect on ergonomics**: gives up per-layer error type customization.
`RawValue.Error` is L2's error, not L3's. The whole point of approach
12+13 was to let L3 wrap L2 with its own policy *and its own error
type*. V5 forces every layer to share L2's nested error.

**Effect on the followup § 7 promise**: the followup template prescribed
per-(Tag, RawValue) `Error` typealiases so that `Kernel.File.Stats.Error`
could resolve to the L3-policy error. V5 makes `Kernel.File.Stats.Error`
unreachable through the Tagged abstraction; consumers would instead
write `Kernel.File.Stats.RawValue.Error`, breaking the abstraction
barrier the unifier was supposed to provide.

**Verdict**: does not preserve the L3-policy ergonomics. Equivalent in
practice to fresh-enum-at-L3 minus the namespace cost.

#### E.2 V6 — Declare typealiases on RawValue's home rather than as constrained Tagged extension

Per-layer error types live as nested types on the L2 RawValue: e.g.,
`extension ISO_9945.Kernel.File.Stats { public typealias Error = ... }`.

**Effect on ergonomics**: same as V5. The per-layer error type lives on
the L2 type; `Tagged<L3-Namespace, L2-Type>.Error` cannot reach it
without re-introducing the same constrained-extension typealias that V5
removed.

**Verdict**: structurally equivalent to V5. Does not preserve per-layer
error type customization.

#### E.3 V7 — Distinct nested-typealias names per leg

Each constrained extension declares a leg-specific name:
`POSIXError`, `MemoryError`, `WindowsError`. No two extensions
ever declare the same name, so lookup never gathers multiple
candidates.

**Effect on ergonomics**: breaks the ecosystem-wide convention of
nested error types being named `.Error`. Every consumer must know
which leg they are in to spell the error type. Every cross-cutting
helper that wants to handle "any Carrier's error" must enumerate the
leg-specific names.

**Effect on Carrier composition**: the per-leg-error pattern is
incompatible with `some Carrier<L2-Type>` accepting "any layer's
error" — Carrier's `Underlying` resolves to L2, not to the per-leg
wrapping; there is no path for Carrier-driven cross-cutting code to
discover the per-leg error type without per-leg specialization.

**Verdict**: technically correct but dysfunctional for the Carrier-
generic cross-cutting case (followup § 6.1's `describeStats(_ s: some
Carrier<...>)` pattern). Trades one structural problem (lookup
ambiguity) for a worse one (no uniform error-name vocabulary).

#### E.4 V8 — Keep per-leg constrained-extension `.Error` typealiases AND rely on consumer build never importing more than one leg

Production reality: any consumer that imports both swift-posix and
swift-windows (e.g., a cross-platform foundations package) imports both
legs transitively. The "consumer never imports more than one leg" path
holds only for trivial cases. Approach 12+13's value proposition was a
**uniform ecosystem-wide pattern**, not a per-consumer escape hatch.

**Verdict**: not viable in any cross-platform package; refuted by the
ecosystem's transitive-import topology.

#### E.5 Path β — Fresh-enum-at-L3 with explicit per-layer error types

The migration agent's pivot. Each L3 namespace declares its own enum
(distinct from L2's) with its own nested error type:

```swift
// At swift-posix:
extension POSIX.Kernel.File {
    public enum Stats: Sendable {
        public enum Error: Swift.Error { case ... }
        public static func get(...) throws(Error) -> Self { ... }
    }
}
```

**Effect on ergonomics**: distinct nominal types between L2 and L3 (the
"deal-breaker" the principal flagged in the followup §1 reasoning that
drove approach 12+13). Each L3 enum mirrors L2's field shape via either
copy (~10 lines per type) or wrap-as-stored-property.

**Effect on Carrier composition**: lost. Path β does not use Tagged at
the L3 layer, so `some Carrier<L2-Type>` does not transparently accept
the L3 type. Cross-cutting code that wants to accept both layers must
either:
(a) accept `some Carrier<ISO_9945.Kernel.File.Stats>` and lose the L3
type (consumers convert at the call site), or
(b) accept a leg-specific concrete type and lose the cross-cutting
genericity.

**Verdict**: principled answer for the foreseeable future. Is what the
ecosystem already does for the 37 non-corrective namespaces in
Wave 3.5-1..8. Loses the followup § 6's Carrier-driven cross-cutting
helper pattern, which becomes additive-only-where-each-helper-is-
specialized-per-layer.

#### E.6 V9 (deferred) — Single-leg constrained-extension `.Error` per package

A weaker version of approach 12+13: each package declares ONLY its own
leg's `.Error` typealias on Tagged, and never imports another package's
constrained-extension declarations. Mechanically: rely on Swift's module
system to prevent cross-leg import.

**Why this is precarious**: relies on consumer-side import discipline
that the ecosystem cannot enforce. Any consumer that does import two
legs (test targets, integration tests, cross-platform foundation
packages) hits the ambiguity. The discipline is only partial protection.
The followup § 9 generalization table explicitly extended approach 12+13
to legal, syscalls, and TBD — at that breadth, the cross-import
discipline is unsustainable.

**Verdict**: not viable as an ecosystem-wide pattern. Useful only for
single-leg packages with no cross-leg consumers.

#### E.7 Workaround Comparison

| Variant | Tagged abstraction preserved? | Per-layer error customization? | Carrier cross-cutting works? | Cross-import safe? |
|---|:---:|:---:|:---:|:---:|
| V5 — `RawValue.E` routing | Partial | No | Yes (resolves to L2) | Yes |
| V6 — Typealias on RawValue home | Partial | No | Yes (resolves to L2) | Yes |
| V7 — Per-leg-distinct names | Yes | Yes | No | Yes |
| V8 — Single-leg-import discipline | Yes | Yes | Yes | **No** |
| **Path β — Fresh enum at L3** | No (no Tagged at L3) | Yes | No (Carrier requires L2 type) | Yes |
| V9 — Per-package single-leg | Partial | Yes (per-package) | Partial | Partial |

No workaround preserves all four properties simultaneously. The
followup § 7 approach 12+13 was the only shape that promised all four,
and the empirical confirmation refutes it. Path β trades the Carrier
cross-cutting property for cross-import safety; V5/V6 trade per-layer
error customization for cross-cutting; V7 trades cross-cutting for
naming. The trade-off space has no Pareto-optimal point under Swift's
current lookup architecture.

**Production answer**: Path β. The Carrier cross-cutting property
(followup § 6) is not lost permanently — it remains available for the
*non-corrective* 37 Wave 3.5 namespaces (where L2 and L3 share the same
namespace shape) and for any future case where per-layer error
customization is not required. The four corrective namespaces (Stats,
Open, Memory.Map, Time) and their generalized siblings adopt Path β.

## Outcome

**Status**: RECOMMENDATION

### E.1 Answers to the Question Set

| # | Question | Answer |
|---|---|---|
| (a) | Is this a known issue upstream? | **Adjacent issues are tracked, but the disjoint-overload-at-matching-base framing is novel.** SR-5440 / #48014 (closed) covered the wrong-base case; SR-7516 / #50058 (open since 2018, "I haven't seen a principled fix") covers the broader associated-type-resolution-ambiguity class but is not framed as the disjoint-overload case specifically. PR #17168 (2018) explicitly admits "We don't validate conditionality for decls at all yet." |
| (b) | SE proposal in flight? | **No.** SE-0048, SE-0142, SE-0143, SE-0299, SE-0361, SE-0404 are adjacent (some implemented) but none address constraint-aware nested-type lookup. The 2020 forum quote from Anthony Latsis ("we are not supposed to support this kind of conditional type member overloading") is the most recent on-record language-design statement. |
| (c) | What do peer languages do? | **All four surveyed languages (Rust, C++, Haskell, Scala 3) discriminate at lookup, but none use Swift's "name lookup over the union of constrained extensions" approach.** Rust uses trait selection. C++ specializations are unrelated types. Haskell uses type-family reduction. Scala 3 uses path-dependent `memberType` + `asSeenFrom` (and explicitly removed Scala 2's projection form for soundness). Swift's gap is unique. |
| (d) | Swift-side workaround that preserves Tagged + Carrier ergonomics? | **No.** The four candidate workarounds (V5–V8) each give up one of: Tagged abstraction, per-layer error customization, Carrier cross-cutting, or cross-import safety. Path β (fresh-enum-at-L3) is the principled answer for the foreseeable future. |
| (e) | File upstream? At what severity? | **Yes, file as a discrete issue with the disjoint-overload-at-matching-base framing.** Severity: medium — the bug class is real and reproducible, but the language-design position (Latsis 2020) suggests filing is a forcing function for a design discussion, not a bug-fix request. |

### E.2 Recommendations

#### Rec 1 — File upstream as a NEW discrete issue (medium severity)

Author and file a swiftlang/swift issue with:

- **Title**: "Same-name nested typealiases on disjoint constrained
  extensions of a generic type produce ambiguous lookup at a base
  satisfying only one"
- **Reproducer**: minimal 4-target SwiftPM package adapted from the
  companion experiment (or pasted as 4 files inline).
- **Expected behavior**: `S<Int>.A` discriminates by where-clause; only
  `extension S where T == Int { typealias A = ... }` participates as a
  candidate.
- **Actual behavior**: lookup gathers all candidates from all
  extensions; `applyGenericArguments` validates per-candidate but
  does not multi-candidate-disambiguate; ambiguity error.
- **Distinguish from prior issues**: explicitly cite #48014 (wrong-base,
  closed) and #50058 (broader, open) and articulate that this is
  neither's exact framing — it is the disjoint-overload-at-matching-
  base specialization.
- **Cite cross-language prior art**: Rust trait projection, Scala 3
  `memberType`, etc. Frame the issue as "Swift's lookup architecture
  diverges from peer languages on this axis" rather than "this is
  a bug in our implementation."
- **Acknowledge the language-design position**: cite Latsis 2020
  forum quote and ask whether the position has changed; if not, ask
  whether an SE proposal would be the appropriate remediation surface.

The filing is a *forcing function* for design discussion, not a bug-fix
request. The Swift core team's stated position is that this is not how
the language is designed; the issue exists to articulate the cost of
that design position to ecosystem-wide layered APIs and to ask whether
the position should change.

#### Rec 2 — Codify in [PLAT-ARCH-*] / [API-IMPL-*] skill rules

Add a new ecosystem rule (suggested ID: `[PLAT-ARCH-019]` or next
available; final ID per skill-lifecycle codification cycle):

> **Statement**: Same-name nested typealiases MUST NOT be declared on
> disjoint constrained extensions of the same generic type. Every nested
> typealias on a generic type's constrained extension MUST be either
> (a) declared on a single canonical constrained extension and routed
> via that extension's where-clause, OR (b) declared with a leg-specific
> name that does not collide with any other constrained-extension
> declaration on the same generic type.
>
> **Why**: Swift's nested-type lookup gathers all matching candidates
> from extensions in scope without filtering by where-clause; two
> declarations on disjoint instantiations produce an ambiguity error at
> every consumer site.
>
> **How to apply**: Reject any pattern of the form
> `extension Tagged where Tag == X { typealias E = ... }` and
> `extension Tagged where Tag == Y { typealias E = ... }` co-existing.
> The followup-approach-12+13 template specifically falls under this
> rule. Path β (fresh-enum-at-L3) is the canonical alternative.
>
> **Reference**: this research document.

#### Rec 3 — Treat Path β as canonical for L2/L3 spec/policy boundaries

For the four corrective namespaces (Stats, Open, Memory.Map, Time) and
all future spec/policy boundaries enumerated in followup § 9, adopt
Path β. The Carrier cross-cutting promise (followup § 6) is preserved
*outside* the per-layer-error-type case (e.g., for the 37 non-corrective
Wave 3.5 namespaces that do not require per-layer error customization).

The followup doc § 7 dispatch instructions for approach 12+13 are
**superseded** for any namespace requiring per-layer error types. The
followup doc itself is updated with a "Status update 2026-05-02 post-
experiment" note cross-referencing this document and the experiment.

#### Rec 4 — Establish ecosystem-wide expectation: the gap is
permanent for the foreseeable future

The Latsis "I haven't seen a principled fix" admission, the SR-7516
issue's eight-year "in progress" status, and the absence of any SE
proposal mean that the gap is unlikely to close in any near horizon.
Future ecosystem decisions touching constrained-extension nested
typealiases should treat the gap as permanent and design around it.

The exception is if the upstream filing (Rec 1) succeeds in opening a
formal SE process. In that case, this document's recommendations would
be revisited; the codified rule (Rec 2) would gain a sunset clause; and
Path β might revert to approach 12+13 for the affected namespaces. This
is a hypothetical the ecosystem should not plan against.

### E.3 Out of Scope

This document does NOT:

- Modify any swift-foundations/swift-posix L3 file (the parallel
  migration agent owns that surface).
- File the upstream issue. The filing is a separate authorization step
  per `feedback_no_public_or_tag_without_explicit_yes.md`.
- Codify the gap into a numbered [PLAT-ARCH-*] requirement. The
  codification is a separate cycle through the skill-lifecycle skill.
- Test V5+ workaround variants in the experiment. The prior-art
  investigation showed the candidate workarounds either give up the
  per-layer-error-customization property (V5, V6) or break ecosystem
  conventions (V7, V8). Per [EXP-011a] first-clean-signal-is-the-
  result, V1–V4's clean ambiguity signal is the result; further
  empirical work would not change the recommendation.

## Blog Potential

This research has been captured as a blog idea:

- [BLOG-IDEA-077: We tried Tagged + Carrier across the layer boundary. Swift's name lookup said no.](../Blog/_index.json) — *Ready for Drafting*

The intended writing mode per [BLOG-010] is first-principles: the discovery
journey from "this should work" through the empirical four-target experiment
to the cross-language survey to Path β is exactly the arc that produces the
lesson. May be a 2-part series with a Lessons Learned narrative followed by
a Technical Deep Dive on Swift's lookup-then-validate vs solver-driven
discrimination, or a single dense Lessons Learned post — writer's call.

## Related Pitches

This research motivated:

- [PITCH-0002 Constraint-Aware Nested-Type Lookup on Constrained Extensions](../Swift-Evolution/Drafts/PITCH-0002%20Constraint-Aware%20Nested-Type%20Lookup.md)
  (DRAFT, 2026-05-02) — proposes a lookup-time filter that consults each
  candidate's enclosing constrained-extension where-clause against the
  parent type's substitution map.

Adjacent prior pitch:

- [PITCH-0001 Allow Protocols Nested in Generic Types Without Capture](../Swift-Evolution/Drafts/PITCH-0001%20Allow%20Protocols%20Nested%20in%20Generic%20Types%20Without%20Capture.md)
  (DRAFT, 2026-02-13) — covers a structurally adjacent gap on the same
  compiler surface (`lib/Sema/TypeCheckType.cpp` + `lib/AST/NameLookup.cpp`).

## References

### Primary sources (this document, verified 2026-05-02)

- **Companion experiment**:
  `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/`
  — 4-target SwiftPM package, ~80 LOC, `Outputs/build-debug.txt` carries
  the verbatim ambiguity diagnostic.

### Adjacent ecosystem prior art

- [`nested-protocols-in-generic-types.md`](nested-protocols-in-generic-types.md)
  — DECISION, 2026-02-13, tier 3.
- [`nested-protocols-literature-study.md`](nested-protocols-literature-study.md)
  — RECOMMENDATION, 2026-02-13, tier 3, depends_on the above.
- [`cross-domain-init-overload-resolution-footgun.md`](cross-domain-init-overload-resolution-footgun.md)
  — RECOMMENDATION, 2026-02-11, value-level analog.
- [`implicit-member-init-resolution-hazard.md`](implicit-member-init-resolution-hazard.md)
  — DECISION, 2026-03-10, tier 3, generalizes the init-overload case.
- [`l3-policy-layering-without-spi-2026-05-02.md`](l3-policy-layering-without-spi-2026-05-02.md)
  — RECOMMENDATION, 2026-05-02, approaches 1–10.
- [`l3-policy-layering-without-spi-2026-05-02-followup.md`](l3-policy-layering-without-spi-2026-05-02-followup.md)
  — RECOMMENDATION, 2026-05-02, approaches 11+12+13 (this document
  refutes § 7's primary recommendation at production scale).

### Swift compiler issues, PRs, and forum threads (verified 2026-05-02)

- [`swiftlang/swift#48014` (SR-5440)](https://github.com/swiftlang/swift/issues/48014)
  — *"Typealias in constrained extension misinterprets the where clause."*
  Closed via PR #28275. Wrong-base case.
- [`swiftlang/swift#50058` (SR-7516)](https://github.com/swiftlang/swift/issues/50058)
  — *"Compiler accepts ambiguous and/or invalid use of associated types."*
  Open, in progress, assignee @AnthonyLatsis. Broader ambiguity class.
- [`swiftlang/swift#28275`](https://github.com/swiftlang/swift/pull/28275)
  — *"Check generic requirements of parent context when realizing
  non-generic types."* Merged 2019-11-15, slavapestov.
- [`swiftlang/swift#17168`](https://github.com/swiftlang/swift/pull/17168)
  — *"[Sema] More aggressive consideration of conditionally defined types
  in expressions."* Merged 2018-06-14, huonw. Quote: "We don't validate
  conditionality for decls at all yet."
- [`swiftlang/swift#30700`](https://github.com/swiftlang/swift/pull/30700)
  — Latsis fix for SR-7516 partial: "everything except for associated
  type resolution ambiguities."
- [forums.swift.org/t/typealias-in-constrained-extension-should-this-compile/34863](https://forums.swift.org/t/typealias-in-constrained-extension-should-this-compile/34863)
  — Latsis 2020 quote: "we are not supposed to support this kind of
  conditional type member overloading."
- [forums.swift.org/t/how-to-select-different-associated-type-based-on-type-constraints/17214](https://forums.swift.org/t/how-to-select-different-associated-type-based-on-type-constraints/17214)
  — Latsis 2018 quote: typealiases are not overloads, second decl is
  redeclaration; constrained-extension overloading is a separate
  question.

### Closely-related open issues

- [`swiftlang/swift#46458` (SR-3873)](https://github.com/swiftlang/swift/issues/46458)
- [`swiftlang/swift#49765` (SR-7217)](https://github.com/swiftlang/swift/issues/49765)
- [`swiftlang/swift#83564`](https://github.com/swiftlang/swift/issues/83564)
- [`swiftlang/swift#87030`](https://github.com/swiftlang/swift/issues/87030)
- [`swiftlang/swift#87839`](https://github.com/swiftlang/swift/issues/87839)

### SE proposals (adjacent, not addressing the gap)

- [SE-0048: Generic Typealiases](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0048-generic-typealias.md)
- [SE-0142: Associated Types with where Clauses](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0142-associated-types-constraints.md)
- [SE-0143: Conditional Conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0143-conditional-conformances.md)
- [SE-0299: Extending Static Member Lookup in Generic Contexts](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md)
- [SE-0361: Extensions on Bound Generic Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0361-bound-generic-extensions.md)
- [SE-0404: Allow Protocols to be Nested in Non-Generic Contexts](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0404-nested-protocols.md)

### Cross-language primary sources (verified 2026-05-02)

#### Rust
- [Rust Reference — Implementations](https://doc.rust-lang.org/reference/items/implementations.html)
- [rustc-dev-guide — Specialization](https://rustc-dev-guide.rust-lang.org/traits/specialization.html)
- [`rustc_trait_selection::traits::project`](https://doc.rust-lang.org/nightly/nightly-rustc/rustc_trait_selection/traits/project/index.html)
- [rustc-dev-guide — Trait solving](https://rustc-dev-guide.rust-lang.org/traits/resolution.html)

#### C++
- [C++ working draft — `[temp.spec.partial]`](https://eel.is/c++draft/temp.spec.partial)
- [C++23 N4868 — `[temp.expl.spec]`](https://timsong-cpp.github.io/cppwp/n4868/temp.expl.spec)
- [C++23 N4868 — `[temp.class.spec]`](https://timsong-cpp.github.io/cppwp/n4868/temp.class.spec)

#### Haskell
- [GHC User's Guide — Type Families](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/type_families.html)
- [HaskellWiki — GHC/Type families](https://wiki.haskell.org/GHC/Type_families)
- Eisenberg, Vytiniotis, Peyton Jones, Weirich. "Closed Type Families
  with Overlapping Equations." POPL 2014.
  [PDF](https://simon.peytonjones.org/assets/pdfs/closed-type-families.pdf)

#### Scala
- [Scala 3 Specification — 03-types](https://www.scala-lang.org/files/archive/spec/3.4/03-types.html)
- [Scala 3 work-in-progress spec announcement](https://www.scala-lang.org/blog/2023/09/25/work-in-progress-scala-3-specification.html)
- Amin, Rompf. "Type Soundness for Dependent Object Types (DOT)." OOPSLA 2016.
  [PDF](https://www.cs.purdue.edu/homes/rompf/papers/rompf-oopsla16.pdf)

### Swift compiler source citations (verified via parallel subagent against `swiftlang/swift` `main` 2026-05-02)

- `lib/AST/NameLookup.cpp` — `DeclContext::lookupQualified`
  (top-level driver, constraint-agnostic)
- `lib/Sema/TypeCheckNameLookup.cpp` — `TypeChecker::lookupMemberType`
  (deduplicates by canonical type)
- `lib/Sema/TypeCheckType.cpp` — `TypeResolver::applyGenericArguments` →
  `checkContextualRequirements` (per-candidate validation)
- `docs/Generics/chapters/type-resolution.tex` — documents
  `applyGenericArguments` as "build a substitution map from the base
  type and generic arguments and check requirements of a generic
  declaration"; no documented multi-candidate disambiguator at
  `lookupQualified`.

### Verification gaps

The two academic PDFs (Eisenberg POPL 2014, Amin & Rompf OOPSLA 2016)
were cited from canonical author/conference URLs but the verification
subagent's `WebFetch` returned encoded binary data rather than extracted
text; verbatim quotes from these papers are NOT used in this document.
The mechanisms attributed (apartness for closed type families;
`memberType`/`asSeenFrom` formalization in DOT) are corroborated by the
GHC User's Guide and Scala 3 specification respectively, both of which
were extracted verbatim. [Verified: 2026-05-02 via parallel subagent
verification].
