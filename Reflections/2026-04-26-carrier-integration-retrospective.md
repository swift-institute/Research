# Carrier Integration — Session Retrospective

<!--
---
date: 2026-04-26
type: reflection
status: COMPLETE
scope: cross-package
related:
  - swift-institute/Research/carrier-ecosystem-application-inventory.md
  - swift-institute/Research/operator-ergonomics-and-carrier-migration.md
  - swift-carrier-primitives/Research/capability-lift-pattern.md (v1.2.0)
---
-->

## Intended scope

### Original handoff

`swift-carrier-primitives/HANDOFF-ecosystem-application-inventory.md` —
two-phase investigation:

- **Phase 1 inventory** — survey swift-primitives + swift-standards + swift-foundations for Carrier conformance / Tagged refactor / `.Protocol` capability-lift candidates.
- **Phase 2 triage** — CAN/SHOULD verdicts per candidate.

**Out of scope (per handoff)**: implementing any conformances. Inventory and triage only.

**Output**: `swift-institute/Research/carrier-ecosystem-application-inventory.md` v1.0.0 with top-5 ranked dispatch targets.

### Scope evolution during session

The user expanded scope through a series of directives:

1. *"Lets make a phased implementation, starting with the easiest to convert/adopt."*
2. *"tagged-primitives should depend directly on carrier-primitives and integrate directly (no trait guard)."*
3. *"Soft deprecation first to get it building and tests passing. then Hard migration in same chat."*
4. *"should we not phase out the *.Protocol approach in favor of Carrier<*>?"*

The implicit operational goal became: **migrate the primitives ecosystem from per-type capability-lift protocols to a unified `Carrier<Underlying>` super-protocol, with `Tagged: Carrier` providing the cascade.**

### Final delivered scope

- Phase 1 inventory + triage (planned)
- Phase 1 implementation: `Tagged: Carrier` cascading conformance (added)
- Phase 2a soft deprecation across three per-type protocols (added)
- Phase 2b hard migration with selective retention via Option G (added)
- Phase 3 partial: Clock + Property Carrier conformances (added)
- Phase 5 verification: Index.Bounded cascade ALREADY-MET (added)
- Three research artifacts authored or amended

## What went right

### Architecturally

1. **`Tagged: Carrier` cascading conformance** — `where RawValue: Carrier` with `Underlying = RawValue.Underlying` is a single extension that automatically lifts every Tagged-aliased ecosystem type into Carrier. ~80 typealias sites became Carriers without per-site work. Verified empirically with cascade tests including nested Tagged.

2. **Cardinal & Affine.Discrete.Vector migrations were mechanical** — once the pattern was established (`Self + Self` operators slot into `Carrier where Underlying == X` extensions), both packages migrated cleanly. ~150 LOC of per-type protocol declarations + Tagged forwarding extensions removed; Carrier conformance one-liner replaced them.

3. **Property Q2 conformance worked first try** — the four-quadrant Carrier design holds up. Property's `~Copyable` Base, the `_read { yield _base }` accessor, and the consuming init satisfied Carrier's protocol requirements without compiler edge cases.

4. **Phase 5 ALREADY-MET discovery** — verification spike showed `Index.Bounded<N> = Tagged<Tag, Tagged<Bound<N>, Ordinal>>` participates in `Ordinal.\`Protocol\`` automatically via the existing cascading constraint. Saved a planned implementation cycle.

5. **Test integrity** — 344+ tests pass across migrated packages (tagged 65, cardinal 21, ordinal 35, finite 79, clock 96, property 48). Zero regressions. Downstream consumers (kernel, memory, buffer, vector, bit-vector, sequence, stack, queue, list, heap, handle, dimension, index, system, pool) all build clean.

### Process-wise

6. **Research-process resolved the Ordinal wall** — when iterative implementation hit the structural limit (Carrier has no `Count` associatedtype), invoking /research-process produced `operator-ergonomics-and-carrier-migration.md` — a Tier 2 analysis enumerating seven options, identifying Option G (Selective Retention) as the right answer. The research articulated a new role-class (operator-ergonomics protocols) that didn't exist in capability-lift-pattern.md before.

7. **Cross-language prior art validation** — checking Rust (`std::ops::Add::Output`), Haskell (TypeFamilies), Scala (dependent types) confirmed the per-type-protocol-with-associatedtype pattern is universal for operator dispatch. This validated retaining `Ordinal.\`Protocol\`` as the principled choice rather than the path of least resistance.

8. **Recommendation #7 codifies the lesson** — the operator-ergonomics-protocols-stay-distinct rule is now in `capability-lift-pattern.md` v1.2.0. Future migrations have the rule available before they hit the same wall.

9. **`@_disfavoredOverload` for ambiguity resolution** — when both `Tagged: Carrier` (cascading) and `Tagged: Ordinal.\`Protocol\`` (sibling) provide same-signature inits, marking the legacy path disfavored guides Swift's overload resolution cleanly. No wholesale overload addition needed.

## What went wrong

### Strategic missteps

1. **Initial Phase 2b misclassification** — the first attempt removed all three per-type protocols uniformly, treating Cardinal.\`Protocol\`, Ordinal.\`Protocol\`, and Affine.Discrete.Vector.\`Protocol\` as the same kind of pattern. They're not. Cardinal and Affine.Discrete.Vector have Self+Self operators (clean Carrier migration); Ordinal has per-conformer `Count` operators (needs different treatment). The structural difference wasn't articulated until midway through. Cost: substantial backtracking and reverts.

2. **Multiple iterations on Ordinal before research-process** — went through:
   - Remove `Ordinal.\`Protocol\`` entirely (broke ~97 call sites)
   - Self.Domain-derived `Count` typealias on Carrier extension (broke bare `Ordinal + Cardinal`)
   - Per-type extension Self.Count (Swift wouldn't compile — generic Self lookup doesn't see type-extension typealiases)
   - Concrete operator overloads — three-tier (rejected by user as wrong)
   - Method-based migration to `.successor.saturating()` (rejected by user)
   - Eventually: Option G via research-process (the right answer)
   
   Should have invoked /research-process at iteration 2, not 5. Habit gap: defaulted to ad-hoc problem-solving when a structural design question was on the table.

3. **Recommendation #3 misreading on first pass** — read "don't refine Carrier" as "don't have any per-type protocol alongside Carrier", which led toward removing Ordinal.\`Protocol\`. The recommendation specifically prohibits REFINEMENT, not COEXISTENCE. The distinction is load-bearing — Hash/Equation/Comparison already coexist with Carrier per Recommendation #6 — but easy to miss on a fast read. Recommendation #7 v1.2.0 now makes the distinction explicit.

### Implementation friction

4. **MemberImportVisibility friction** — `public import Carrier_Primitives` had to be added to ~30 files across the migration. Several rounds of "build fails because import missing → add import" cycles. This is an upcoming-feature cost; not specific to this migration but cumulative under it.

5. **Stale-build-cache fragility** — multiple times, build errors disappeared after `swift package clean`. Without the clean, errors looked like real compile failures and triggered investigation. Cost: chasing phantom errors that weren't real. Likely a Swift incremental-compile bug under upcoming features (`InternalImportsByDefault`, `MemberImportVisibility`) — worth a minimal reproducer.

6. **Sed-based bulk editing fragility** — sed inserted duplicate `public import Carrier_Primitives` lines in OutputSpan+Cardinal.swift because the file had two MARK comments. Required cleanup. Bulk-edit tools work for simple patterns but break on file-shape variation.

7. **Inventory verdict misclassification — Algebra.Modular.Modulus** — rated CAN-yes in inventory v1.0.0, but the type has `init(_ Cardinal) throws(Error)` — validating wrapper, RawRepresentable territory per `carrier-vs-rawrepresentable-comparative-analysis.md`. The verdict was made without examining the init signatures. Caught only when implementation began.

### Process gaps

8. **Initial overload three-tier proposal** — proposed adding 9 operator overloads (bare + Tagged + commutative + in-place + generic) to recreate the legacy `.one`-inference behavior. User correctly identified this as the wrong approach. The overload approach was symptomatic of trying to preserve behavior without understanding the structural cause (associatedtype Count's per-conformer concreteness). Cost: cycles before reframing.

9. **Initial scope creep without explicit re-scoping** — the handoff was inventory+triage. Implementation expanded organically through user directives. Could have benefitted from an explicit "we're now in implementation mode, handoff scope is superseded" reset. Tracking artifacts (TaskList, status updates) carried legacy assumptions briefly.

10. **Did not produce a plan-of-record before Phase 2b implementation** — went directly into implementing Phase 2b as the user described it, without authoring a plan that could be reviewed before execution. The Option G research came AFTER significant implementation thrashing. A plan-first approach (as embodied in `[RES-011] Research-First Design`) would have surfaced the role-class distinction earlier.

## What we learned

### Pattern-level insights

1. **Per-type protocols come in three role-classes, not two.** capability-lift-pattern.md previously identified two: value-carrying (subsumed by Carrier) and witness (stays distinct, Recommendation #6). This session surfaced a third: **operator-ergonomics protocols** — per-conformer associatedtype like `Count` providing operator dispatch. Carrier cannot subsume them (no associatedtype machinery); refinement triggers V2 cost; siblings are the answer. Recommendation #7 codifies this.

2. **The Self+Self vs Self+Self.Count test is the migration discriminator.** For any per-type protocol being considered for Carrier subsumption, examine its operators:
   - **Self+Self → migrate cleanly** (Carrier-where-Underlying-X extension provides the operator)
   - **Self+Self.Count → retain as sibling** (Count is per-conformer; Carrier has no associatedtype to express it)

3. **Sibling pattern doesn't trigger Recommendation #3's V2 cost.** Refinement (`Foo.\`Protocol\`: Carrier`) requires double-Tagged-conformance. Sibling (no inheritance) doesn't. Hash.\`Protocol\` already demonstrates this — coexists with Carrier without V2 cost.

4. **Cascading conformance via associated-type recursion is powerful.** `Tagged: Carrier where RawValue: Carrier` with `Underlying = RawValue.Underlying` is one extension covering arbitrary nesting depth. The cascade pattern is widely applicable; could see use beyond Tagged.

5. **Universal-adoption signal validates retention.** Rust, Haskell, Scala all use the per-type-protocol-with-associated-type pattern for operator dispatch. The Swift legacy pattern is idiomatic across statically-typed languages — not legacy cruft. The contextualization step in [RES-021] correctly distinguished "universal pattern Swift idiomatically supports" from "absent feature Swift should add".

### Conformance-level insights

6. **Type's actual generic shape constrains Carrier conformance scope.** Property<Tag, Base: ~Copyable> doesn't admit ~Escapable Base. The Carrier conformance must match Property's actual shape (Q1+Q2), not Carrier's full quadrant grid. Trying to widen via the where clause without widening Property itself is unsatisfiable.

7. **Validating-init is the carrier-vs-rawrepresentable boundary.** Any `init(_) throws(Error)` is a validating init — RawRepresentable territory, not Carrier. Algebra.Modular.Modulus's `init(_ Cardinal) throws(Error)` was the tell.

8. **`@_disfavoredOverload` is the targeted disambiguation tool.** When two protocols on the same type provide same-signature methods, marking the legacy/secondary path disfavored guides Swift's overload resolution cleanly without adding wholesale overloads.

### Process-level insights

9. **Research-process is faster than iteration on structural design questions.** When the Ordinal wall hit, going through /research-process methodically (enumerate options, identify criteria, compare against constraints, recommend) produced Option G in less wall-clock time than the prior iterative trial-and-error. Should be the DEFAULT for design questions, not a fallback.

10. **Inventory verdicts should be hypotheses, not commitments.** Algebra.Modular.Modulus's misclassification shows that inventory-time analysis can miss type-level details. Verdicts work better as "CAN-yes, pending init-signature verification" than "CAN-yes, ready to apply."

11. **Recommendation precision matters at the read site.** "Don't refine Carrier" reads as a strong rule, but the cost it cites (V2 double-Tagged-conformance) is specific to refinement. Sibling protocols are unaffected. Recommendations should make these distinctions explicit so first-time readers don't conflate similar patterns.

## Suggestions for improvements / research

Prioritized by leverage and ease:

### Tier 1 — Direct skill / convention amendments

1. **Amend the `primitives` skill's static Tier 0 list.** `swift-tagged-primitives` moved Tier 0 → Tier 1 in this session. The skill's [PRIM-ARCH-001] table includes a hardcoded Tier 0 list that needs updating. Concrete action: remove `swift-tagged-primitives` from the Tier 0 list; add a note about the carrier-primitives-driven reassignment.

2. **Promote the Self+Self vs Self+Self.Count test to a general migration-triage rule.** Recommendation #7 captures it for Carrier specifically; could be more broadly applicable. Concrete action: add a sub-rule under [IMPL-*] or [API-LAYER-*] documenting the operator-shape discriminator.

3. **Document `@_disfavoredOverload` patterns in the implementation skill.** This session used @_disfavoredOverload for protocol-conformance disambiguation. The pattern isn't documented elsewhere I found.

### Tier 2 — Process improvements with named hooks

4. **Make /research-process the default for blocked structural design questions.** Currently it's available but not enforced. Concrete action: add a rule to the implementation skill: "If a structural design question blocks implementation for >2 iteration cycles, invoke /research-process before continuing." Could integrate with [RES-011] (Research-First Design).

5. **Inventory verdict validation step.** Extend `audit-finding-triage-taxonomy.md` (currently IN_PROGRESS) to require: "CAN-yes verdicts on Carrier conformance candidates MUST verify (a) init signatures don't include `throws` (else RawRepresentable territory), (b) generic constraint admits the proposed Underlying constraint, (c) operator shape matches Self+Self (else operator-ergonomics-protocol territory per Recommendation #7)."

6. **Pre-implementation verification spike per [RES-021] for Carrier conformances.** For any Tier 2+ Carrier conformance, do a minimal isolated test BEFORE landing the production conformance. Codifies the spike pattern and catches Algebra.Modular.Modulus-style misclassifications upfront.

### Tier 3 — Research topics worth investigating

7. **Cross-Carrier algorithm catalog and demand survey.** Recommendation #5 says Carrier migration should be driven by Form-D demand. But: have any cross-Carrier algorithms been written post-migration? If demand is unrealized, the Carrier capability is unused — important to understand whether (a) demand will emerge over time, (b) consumers don't know the capability exists, (c) Form-D was the wrong target. Survey: search ecosystem for `<C: Carrier>` usage post-migration.

8. **MemberImportVisibility transitive-import pattern.** Ecosystem-internal cross-package conformances cause import-cascade friction. Research: is there a pattern (transitive `public import`, `@_exported` re-export, trait-gated visibility) that lets consumers see ecosystem extensions without enumerating imports? Could be a Swift Forums discussion.

9. **Stale-build-cache reproducer for upcoming features.** Multiple "errors disappear after swift package clean" moments during this session. Could be a known Swift bug or unintended interaction between `InternalImportsByDefault`/`MemberImportVisibility` and incremental compilation. Worth a minimal reproducer + Swift Forums issue per `issue-investigation` skill.

10. **Property Q3/Q4 widening study.** Property currently doesn't admit ~Escapable Base. Q3/Q4 Carrier conformance requires widening the generic. Research: do Property's `_modify`, fluent accessors, and downstream consumers (stack/queue/list/heap) survive ~Escapable Base? Worth doing only if a concrete Q3/Q4 consumer demand surfaces (per [RES-018]).

11. **Decimal Tagged refactor design.** Phase 4 of the original plan, not attempted this session. Needs focused research: migration path for `Decimal.Exponent`'s manually-rolled arithmetic to `Tagged<Tag, Int>` extensions; consumer migration scope; breaking-change blast-radius. Should produce a per-package handoff before implementation.

12. **Carrier coverage map across ecosystem types.** With Phase 1+2+3 done, what fraction of value-wrapping types are now Carriers? What's missing? A "Carrier coverage" diagnostic that walks the ecosystem and reports unconverted candidates would track migration completeness over time.

### Tier 4 — Speculative / lower-priority

13. **Carrier subsumption-boundary consolidation.** capability-lift-pattern.md has Recommendations #5 (when not to migrate Cardinal/Ordinal "today"), #6 (witness protocols stay distinct), #7 (operator-ergonomics protocols stay distinct), plus 14 sli-*.md docs (per-stdlib-type decisions). The "What does Carrier subsume vs what stays distinct?" picture is articulated piecemeal. A consolidated reference would help future migration decisions. Tier 1-2 research scope.

14. **Tagged: Carrier cascade limits.** The `Underlying = RawValue.Underlying` cascade works. But: are there shapes it breaks down? Generic RawValue (per V5a in capability-lift-pattern.md), ~Copyable RawValue (V5b), existential RawValue (V5c) all have caveats. Worth empirical verification under the production cascade.

15. **Tier 0 → Tier 1 cascade analysis.** `swift-tagged-primitives` moved tiers. Does this affect downstream packages' tier classifications? A diagnostic that walks the dep graph + computes tier reassignments would catch silent shifts.

## Net assessment

The migration delivered **real capability** (Carrier as cross-type super-protocol; ~80 ecosystem types now first-class Carriers; Form-D dispatch writable) at **non-trivial process cost** (multiple iterations, scope creep, late research-process invocation, ~30 files touched for import friction).

**The Carrier capability is unused so far** in production cross-Carrier algorithms; the migration's ROI hinges on whether Form-D demand materializes. Recommendation #5 was prescient — migration should have been demand-driven, not factored-for-its-own-sake. Whether this session was premature depends on whether the new capability gets used.

**The Option G outcome is correct.** Selective retention (per-type protocols with `Count` machinery stay sibling to Carrier) preserves operator ergonomics, aligns with universal cross-language prior art, and matches the existing Hash/Equation/Comparison precedent. Recommendation #7 codifies this so future migrations don't re-derive the lesson.

**The biggest single improvement opportunity** is invoking /research-process EARLIER when structural design questions arise. Late research-process produced Option G; early research-process would have produced Option G AND avoided ~3 iteration cycles. The skill is available; the habit needs strengthening.

## References

- `swift-institute/Research/carrier-ecosystem-application-inventory.md` v1.1.0 — Phase 1 inventory + triage + implementation log
- `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` v1.0.0 — Tier 2 research investigation resolving Phase 2b
- `swift-carrier-primitives/Research/capability-lift-pattern.md` v1.2.0 — Recommendation #7 codifying operator-ergonomics-protocols-as-siblings
- `swift-carrier-primitives/Research/carrier-vs-rawrepresentable-comparative-analysis.md` — boundary between Carrier and validating-wrapper space (used to reclassify Algebra.Modular.Modulus)
- Tagged: Carrier conformance — `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+Carrier.swift`
- Cardinal/Ordinal/Affine.Discrete.Vector Carrier conformances — respective package `Sources/.../X+Carrier.swift` files
- Clock.Nanoseconds/Clock.Offset Carrier conformances — `swift-clock-primitives/Sources/Clock Primitives/Clock.X+Carrier.swift`
- Property Carrier conformance — `swift-property-primitives/Sources/Property Primitives Core/Property+Carrier.swift`
