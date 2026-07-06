# Generics Manifesto — Implementation Inventory as of Swift 6.4

**Date**: 2026-07-02
**Verified against**: local clone `/Users/coen/Developer/swiftlang/swift`, branch `release/6.4.x`, HEAD `d4b6546ae0d9463a76057eb9b0f22cc05ffe12ca` (2026-06-30)
**Source document**: [`docs/GenericsManifesto.md`](https://github.com/swiftlang/swift/blob/main/docs/GenericsManifesto.md) (line numbers below reference the clone's copy)

Of the manifesto's 28 items: **16 not implemented, 4 partially implemented, 11 implemented** (nested generics counted once with its carve-out noted).

---

## Not implemented as of Swift 6.4 (16 items)

| Manifesto item | Manifesto line | Evidence in 6.4 tree |
|---|---|---|
| Generic associatedtypes | :91 | Parser hard-rejects: "associated types must not have a generic parameter list" (`include/swift/AST/DiagnosticsParse.def:364`) |
| Generic constants | :142 | No support; only functions, types, typealiases, and subscripts can have generic parameter lists |
| **Parameterized extensions** | :152 | Grep over `lib/Parse` + `lib/Sema` + `include/` finds nothing; no flag in `Features.def`. `extension<T> Array where Element == T?` remains unwritable. The ~2021 experimental implementation attempt never landed. Closest shipped mechanisms: same-type-constrained extension over a helper protocol, or SE-0361 bound-generic extension sugar — neither introduces a new type parameter |
| Default generic arguments | :240 | No support, no feature flag |
| Generalized supertype constraints | :276 | `where U: T` with `T` a generic parameter still rejected; superclass bounds must be concrete class types |
| Subclasses overriding requirements satisfied by defaults | :291 | Marked (\*) in the manifesto, but the long-standing limitation persists — a non-final class inheriting a protocol-extension default can't have subclasses re-satisfy the requirement dynamically |
| Extensions of structural types | :424 | `extension (T, U)` / tuple conformances gated behind `EXPERIMENTAL_FEATURE(TupleConformances, false)` (`include/swift/Basic/Features.def:349`). SE-0283 (tuples: Equatable/Hashable/Comparable) accepted but implementation reverted, never shipped; stdlib tuple `==` is still ad-hoc overloads up to arity 6. Function-type extensions: nothing |
| Default implementations *inside* protocol bodies | :452 | Only protocol extensions provide defaults; bodies in the protocol declaration itself are rejected |
| Dynamic dispatch for protocol-extension members | :543 | Extension members remain statically dispatched |
| Named generic parameters | :573 | Not implemented |
| Higher-kinded types | :599 | Not implemented |
| Explicit type arguments at call sites (`f<Int>(x)`) | :619 | Still diagnosed: "cannot explicitly specialize" (`include/swift/AST/DiagnosticsSema.def:4956`). Note: 6.4's `@specialized`/`@_specialize` attributes are pre-specialization hints, not call-site type application |
| Generic protocols | :639 | Deliberately not pursued; SE-0346 primary associated types took the manifesto's use case, but a protocol still cannot abstract over "conforms in multiple ways" |
| Private conformances | :675 | No implementation, no feature flag in 6.4 (pitches exist, nothing landed) |
| Retroactive protocol refinement | :697 | Not implemented ("unlikely" per manifesto). Distinct from SE-0364 `@retroactive`, which annotates retroactive *conformances*, not refinement |
| Removal of associated type inference | :731 | The "potential removal" never happened; inference retained (reworked over the years for correctness) |

---

## Partially implemented (4 items)

| Manifesto item | Line | Shipped | Still missing in 6.4 |
|---|---|---|---|
| Variadic generics | :351 | Parameter packs SE-0393/0398/0399 (Swift 5.9); pack iteration SE-0408 (Swift 6.0) | Same-element requirements (`repeat each T == Int`) — "same-element requirements are not yet supported" (`include/swift/AST/DiagnosticsSema.def:3525`); no pack destructuring/indexing; no stored-property packs (the manifesto's `ZipIterator` with stored pack fields still isn't directly expressible) |
| Generic value parameters | :583 | SE-0452 integer generics — **baseline** in 6.4 (`Features.def:259`, `BASELINE_LANGUAGE_FEATURE(ValueGenerics, 452, …)`); SE-0483 `InlineArray` type sugar (`Features.def:275`) | Only `Int`-valued parameters; the manifesto's `String`-parameterized example (and any non-integer value type) is unsupported |
| Generalized existentials | :754 | SE-0353 constrained existentials, `any Collection<Int>` (Swift 5.7) | Constraints limited to primary associated types; arbitrary `where`-clause existentials (e.g. constraining a non-primary path like `.Iterator.Element`) not expressible |
| Opening existentials | :781 | SE-0352 implicit opening at generic call sites (Swift 5.7; `UPCOMING_FEATURE(ImplicitOpenExistentials, 352, v6)`, `Features.def:312`) | No explicit opening syntax (the manifesto's `openas` / named dynamic type); `_openExistential` remains an underscored internal |

---

## Implemented (11 items)

| Manifesto item | Line | Shipped in |
|---|---|---|
| Recursive protocol constraints (\*) | :28 | SE-0157, Swift 4.1 |
| Nested generics | :44 | Swift 3.1 — carve-out: protocols still can't nest in *generic* contexts (SE-0404, Swift 5.10, covers non-generic nesting only) |
| Concrete same-type requirements | :58 | Swift 3.1 (`extension Array where Element == String`) |
| Generic typealiases | :78 | SE-0048, Swift 3.0 |
| Generic subscripts | :115 | SE-0148, Swift 4.0 |
| Arbitrary requirements in protocols (\*) | :211 | SE-0142, Swift 4.0 |
| Typealiases in protocols and protocol extensions (\*) | :227 | SE-0092, Swift 3.0 |
| Generalized `class` constraints | :254 | SE-0156, Swift 4.0 |
| Conditional conformances (\*) | :323 | SE-0143, Swift 4.1 — manifesto-noted restriction stands: at most one conformance per type/protocol pair (no overlapping conditional conformances) |
| `where` clause after the signature (\*) | :497 | SE-0081, Swift 3.0 |
| `protocol<...>` → `P & Q` (\*) | :514 | SE-0095, Swift 3.0 |

---

## Why each missing item is missing (potential reasons)

Sourced from the manifesto's own commentary, Swift Evolution review threads, and the compiler's architectural constraints. Recurring root causes:

- **Coherence** — the runtime model allows at most one globally visible conformance per type/protocol pair; `as?` casting depends on it.
- **Witness-table ABI** — conformances are fixed-layout tables emitted at compile time; runtime synthesis or variable-shape tables need new runtime machinery.
- **Requirement Machine decidability** — generic signatures are solved by a term-rewriting system (Swift 5.6+) that must remain finite/confluent.
- **Superseded** — primary associated types (SE-0346), parameter packs (SE-0393+), and bound-generic extensions (SE-0361) absorbed the motivating demand.

### Not-implemented items

| Item | Potential reason(s) |
|---|---|
| Generic associatedtypes | Amounts to type-level lambdas (the manifesto says so at :113): conformances would supply type *functions*, not types. The Requirement Machine models associated types as symbols in a finitely-presented monoid; parameterized ones break finiteness/decidability. Witness tables have no representation for an unapplied type function. Demand largely absorbed by primary associated types + packs. |
| Generic constants | Semantically incoherent as stated: a `let` with type parameters is not one constant but a family — per-instantiation storage has no home (no enclosing metadata to hang it on), so it degenerates to a nullary generic function. Static members of generic types already cover the use case. Never seriously pitched. |
| Parameterized extensions | An experimental implementation (PR #34816, 2021) existed but never landed and bit-rotted. Core difficulty: the extension's parameters must be *inferred by pattern-matching the extended type* (`extension<T> Array where Element == T?`), a unification mode conformance lookup doesn't have — a conformance declared this way must be found by matching arbitrary bound types against a parameterized pattern. SE-0361 sugar + helper protocols cover most motivating examples, draining champion energy. Priorities went to packs/ownership/concurrency. |
| Default generic arguments | Pitched repeatedly (2017–2018 threads); stalled on inference interaction: when does the default win vs. bidirectional inference from arguments/context? Every proposed rule produced surprising results at call sites, and the core team asked for a complete story that never materialized. Also a source-compat hazard: adding a defaulted parameter to an existing generic type changes overload/inference behavior. |
| Generalized supertype constraints | Superclass requirements in the generic signature assume a *concrete* class bound (anchors layout, vtable, and cast strategy); an abstract bound (`where U: T`, `T` a parameter) needs new Requirement Machine support for class hierarchies over variables. Narrow demand (NSCoder-style APIs), usually workaround-able with casts, so never prioritized. |
| Subclass override of extension defaults | The default is statically copied into the class's witness table at conformance time; letting subclasses re-satisfy it requires override-able (vtable-like) witness entries — an ABI change with resilience and devirtualization costs. Also a semantic objection: silently making every defaulted requirement a customization point changes existing behavior. Official position remains "declare it as a requirement". |
| Extensions of structural types | Structural types have no declaration to anchor members/conformances/metadata on. Tuples specifically: a conformance for *arbitrary arity* is inherently variadic — impossible before parameter packs; SE-0283's pre-pack builtin implementation broke dynamic casts and was reverted. The pack-based retry (`TupleConformances`, experimental) is blocked on a coherence problem: single-element tuples collapse (`(T) == T`), so a tuple conformance can overlap/shadow the element's own conformance. |
| Default implementations in protocol bodies | Pure sugar over protocol extensions, so cost/benefit is poor; and the syntax is ambiguous about semantics — a body in the protocol could plausibly mean "default", "final", or "dynamically dispatched default", and hiding the extension/requirement dispatch distinction at the declaration site was judged to worsen, not fix, the confusion. |
| Dynamic dispatch for protocol-extension members | Extension members have no witness-table slot, and extensions are retroactive: a table can't be sized for members added later in other modules. Global/dynamic lookup would break resilience and cross-module coherence (two modules extending the same protocol). Static dispatch is also a deliberate performance guarantee. The 2015–2016 debates ended with "the model is intentional; it's a diagnostics problem". |
| Named generic parameters | Only useful together with explicit call-site type arguments (also unimplemented); near-zero demand since inference handles the cases. Parked as sugar. |
| Higher-kinded types | Requires unification over unapplied type constructors — far beyond the Requirement Machine's rewriting model — and runtime metadata only exists for fully-applied types. Philosophically disfavored: Swift's design culture prefers concrete protocol-oriented modeling over Functor/Monad-style abstraction (the manifesto itself hedges at :599). Pragmatic subsets covered by primary associated types + packs. |
| Explicit type arguments at call sites | Grammar accepts `f<Int>(x)` precisely to reject it (`DiagnosticsSema.def:4956`) — the block is philosophy, not parsing: the core team prefers inference plus value-level `T.Type`/`as` steering, because non-inferable generic parameters are considered an API smell to fix with an explicit parameter. Would also need a story for partial application of type argument lists. |
| Generic protocols | Manifesto argues against it directly (:639): the real demand was "conform in multiple ways", which destroys the one-conformance-per-type model that casting, witness lookup, and extension resolution rely on. Primary associated types (SE-0346) + constrained existentials delivered the ergonomics without breaking coherence. Effectively a won't-do. |
| Private conformances | Manifesto calls global conformance visibility "a feature" (:675): `as?` is a global question, so a file-private conformance either gives location-dependent cast results or requires the runtime to track scopes — neither is sound with current metadata. The "scoped conformances" pitch (2019) and later revivals all stalled on exactly dynamic-cast semantics and witness-table identity. |
| Retroactive protocol refinement | Refining `Collection: Pretty` retroactively would require every already-compiled `Collection` conformance (including in shipped binaries) to grow a `Pretty` witness table — i.e., runtime witness synthesis with whole-program knowledge. Fundamentally incompatible with separate compilation and library evolution. |
| Removal of associated type inference | Removing it is catastrophically source-breaking (every `Sequence`/`Collection` conformance relies on inferring `Element`/`Index`/…) and the ergonomic regression was judged unacceptable. Resolved the other way: the inference implementation was rewritten (circa Swift 5.10) to be predictable instead of being removed. |

### Partial items — why the gaps remain

| Gap | Potential reason(s) |
|---|---|
| Same-element pack requirements (`repeat each T == Int`) | Explicitly deferred from SE-0393. A same-element requirement makes pack expansions unify with scalar types, which both the Requirement Machine and the constraint solver currently treat as distinct shapes; needs per-element rewrite rules. No champion since. |
| Stored property packs / pack destructuring | Struct layout would depend on pack shape → variable-length layouts in nominal types need new ABI + metadata (tuples have it; nominal types don't). Scoped out of 5.9 and not picked back up. |
| Non-integer value generics | SE-0452 restricted to `Int` because type identity now includes values: arguments must have a canonical, decidable, manglable form and runtime metadata encoding. Arbitrary `Equatable` values would make type equality depend on user-defined `==` at runtime (unsound/nonterminating). Each new value kind (Bool, String, other integer types) needs its own mangling + metadata + Requirement Machine support; listed as future work. |
| Full `where`-clause existentials | SE-0353 chose primary associated types as the 80% path; arbitrary requirement signatures on existentials need runtime evaluation of generic requirements during casts, plus unsettled syntax and member-typing rules. Diminishing returns after 0352/0353 shipped. |
| Explicit existential opening (`openas`) | SE-0352's implicit opening covered the dominant need without surfacing "local archetypes" as a nameable language construct — explicit opening raises scoping questions (the opened type escaping its binding). Demand collapsed post-5.7; `_openExistential` suffices internally. |

**Caveat on sourcing**: items with an official record (generic protocols, private conformances, retroactive refinement — argued in the manifesto itself; SE-0283's revert; SE-0393/SE-0452's explicit deferrals; the explicit-specialization diagnostic) are documented decisions. For items with no rejection record (generic constants, named generic parameters, stored property packs), "no champion + low demand" is inference from the absence of evolution activity, not a documented decision.

---

## Forecast — expected landing horizons

Grounded in three signals, strongest first: (1) commit activity on `release/6.4.x` since 2025-07 (`git log --grep` per topic), (2) in-tree experimental flags, (3) explicit SE future-work declarations vs. manifesto won't-dos. Horizons are relative to Swift 6.4 (mid-2026).

**Empirical activity snapshot** (commits since 2025-07): value generics — active (stdlib adoption `#83710`, RequirementMachine diagnostics); parameter packs — maintenance + reflection completion only; existentials — refactoring only; tuple conformances, parameterized extensions, same-element requirements, default generic arguments — zero feature commits.

### Soon (≤ ~1 year)

Nothing has an accepted-pending proposal. The single credible candidate is **broadening value generics beyond `Int`** (other integer types, possibly `Bool`): it is SE-0452's declared future work, the only topic with active feature investment in the 6.4 cycle, and `InlineArray`/`Span` adoption creates sustained pull.

### Medium (~1–3 years)

| Item | Basis |
|---|---|
| Same-element pack requirements | Explicitly deferred from SE-0393 as future work; Requirement Machine infrastructure exists; small, well-understood scope. Dormant (one crash fix this year) but the natural next pack-completion step. |
| Non-integer value generics (beyond integer types) | Continuation of the active value-generics investment; each value kind is incremental mangling/metadata work. |

### Longer term (3+ years; needs a champion or a design breakthrough)

| Item | Blocker to clear |
|---|---|
| Tuple conformances / extensions of structural types | Most likely of this bucket — implementation exists behind `TupleConformances`, but the one-element-tuple coherence problem is unsolved and the flag has had zero commits in a year. |
| Stored property packs / pack destructuring | Variable-shape layout ABI for nominal types; sizable runtime work, no activity. |
| Parameterized extensions | Recurring demand and a prior patch as reference, but needs the pattern-matching conformance-lookup design and a champion; zero activity. |
| Full `where`-clause existentials | Natural SE-0353 extension; needs runtime evaluation of requirement signatures during casts; demand largely satisfied by primary associated types. |
| Default generic arguments | Recurring pitches; lands only if someone solves the inference-interaction story that killed every prior attempt. |
| Generalized supertype constraints | Requirement Machine support for abstract class bounds; narrow demand. |
| Private conformances | Persistent demand keeps it alive, but it lands only with a breakthrough on dynamic-cast semantics; `package` access level (SE-0386) siphoned off part of the motivation. |

### Likely never

| Item | Why closed |
|---|---|
| Generic protocols | Explicit won't-do: breaks one-conformance-per-type coherence; superseded by SE-0346. |
| Higher-kinded types | Beyond the Requirement Machine's model; philosophically disfavored; superseded for pragmatic cases. |
| Generic associatedtypes | HKT-adjacent (type-level lambdas); same objections; superseded by primary associated types + packs. |
| Retroactive protocol refinement | Fundamentally incompatible with separate compilation and library evolution. |
| Removal of associated type inference | Closed — resolved the opposite way (inference rewritten ~5.10, retained). |
| Dynamic dispatch for protocol-extension members | Closed — core team holds the static-dispatch model is intentional; ABI-locked since stability. |
| Subclass override of extension defaults | Witness-table ABI locked since ABI stability; official answer is "declare it as a requirement". |
| Explicit call-site type arguments (`f<Int>(x)`) | Philosophically opposed — the reject-with-diagnostic behavior is the deliberate design; `T.Type` parameters are the endorsed pattern. |
| Named generic parameters | Only meaningful atop explicit type arguments (see above); no independent demand. |
| Generic constants | Degenerate feature (a nullary generic function); no demand ever materialized. |
| Default implementations in protocol bodies | Pure sugar over extensions; a decade without a champion; dispatch-semantics ambiguity unresolved. |
| Explicit existential opening (`openas`) | Superseded by SE-0352 implicit opening; demand collapsed. |

---

## Solveability — candidates an external contributor could pick up

Two axes govern pickup viability: **evolution-approval risk** (is the design already blessed, or is a proposal fight required?) and **technical depth** (bounded Sema/RM work vs. ABI/runtime/design breakthroughs). The gold tier is *blessed-but-unimplemented*: pure engineering, no design fight.

### Tier 1 — blessed design, bounded implementation (genuinely pickable)

| Candidate | Why viable | Entry points | Risk |
|---|---|---|---|
| Same-element pack requirements | Explicitly declared future work in SE-0393 — no evolution fight, or at most a small amendment. Scope is Requirement Machine + constraint solver; no ABI/runtime work. | Rejection: `DiagnosticsSema.def:3525`; known gap: `lib/AST/RequirementMachine/TypeDifference.cpp:164` (`// FIXME: same-element requirements`) | RM internals have a learning curve; but the subsystem is well-documented (`docs/RequirementMachine/`) and actively maintained (review support available). |
| Value generics beyond `Int` (other integer types, `Bool`) | SE-0452's declared future work; the one area with active maintainer investment (stdlib adoption, diagnostics) → engaged reviewers. Largely mechanical per value kind: Sema check relaxation + mangling + runtime metadata. | Int-only enforcement: `DiagnosticsSema.def:8885–8900` (`invalid_value_type_value_generic` et al.) | Touches mangling/ABI — needs runtime-team review; small evolution amendment per value kind. |

### Tier 2 — popular but needs a proposal fight (pickable with staging)

| Candidate | Why plausible | Risk |
|---|---|---|
| Parameterized extensions | Prior implementation (PR #34816) exists as a map; parser/Sema for *member-only* parameterized extensions (no conformances) avoids the hard pattern-matching-conformance-lookup problem entirely. Staged pitch: members first, conformances later. Recurring community demand. | Full evolution proposal required; the conformance half is a real design problem; champion commitment is the price. |

### Tier 3 — blocked on unsolved design problems (effort alone doesn't help)

Tuple conformances (single-element coalescing coherence — even the in-tree experimental implementation is parked on it) · Default generic arguments (inference-interaction story) · Private conformances (dynamic-cast semantics) · Generalized supertype constraints (RM support for abstract class bounds, plus no blessed design).

### Tier 4 — deep ABI/runtime programs or evolution-dead (not pickable)

Stored property packs, full `where`-clause existentials (runtime work at platform scale) · everything in the "likely never" bucket (opposed or superseded — code contributions would be declined regardless of quality).

**Recommendation**: same-element pack requirements is the single best pickup — blessed design, zero ABI surface, a marked FIXME as the trailhead, and it directly completes the variadic-generics story. Value-generics broadening is the runner-up (more mechanical, but touches mangling). Parameterized extensions only with appetite for an evolution campaign.

Of the missing items, parameterized extensions, same-element pack requirements, and non-integer value generics are the three with historical upstream motion; generic associatedtypes and higher-kinded types have had none. There is no experimental flag for parameterized extensions in 6.4 — do not design around the feature existing.
