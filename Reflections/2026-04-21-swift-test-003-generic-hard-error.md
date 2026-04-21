---
date: 2026-04-21
session_objective: Execute handoff-prescribed per-source-module test-target split + [SWIFT-TEST-002] suite-shape migration on swift-property-primitives. Close Property.View.Typed-family + Property.Consuming canonical-recipe coverage gaps.
packages:
  - swift-property-primitives
  - swift-institute/Skills/testing-swiftlang
status: pending
---

# [SWIFT-TEST-003] generic hard error — skill broadening + handoff-prescription reversal

## What Happened

The `swift-property-primitives` handoff prescribed migrating four existing test files from the compound-name `@Suite struct \`Property Tests\`` parallel-namespace shape to `extension Property { @Suite struct Test { ... } }` per `[SWIFT-TEST-002]`. The migration is empirically impossible for this package: the source types (`Property<Tag, Base>`, `Property.View`, `Property.View.Read`, `Property.View.Read.Typed`, and the two new targets' Property.Typed + Property.Consuming) are all generic or nested-in-generic, and the `@Test` macro emits `@section("__DATA_CONST,__swift5_tests")` attributes which the compiler rejects with a **hard error** in a generic context:

```
error: attribute @section cannot be used in a generic context
```

Additionally, test function bodies inside `extension Generic { ... }` are treated as generic functions — blocking patterns like `struct Tag {}` declared inside a test body (`type 'Tag' cannot be nested in generic function ...`).

The existing test files were already in `[SWIFT-TEST-003]` parallel-namespace shape from an earlier release-polish session. The handoff author read that shape as a violation of `[SWIFT-TEST-002]` and prescribed migration without verifying the target would compile against the package's generic types. Phase 4 "migration" reduced to a no-op audit; the two new smoke files (Typed, Consuming) adopted `[SWIFT-TEST-003]` to match.

`[SWIFT-TEST-003]`'s statement read "Generic type specializations MUST use parallel namespace pattern" and described one failure mode: silent non-discovery on concrete specializations like `extension Container<Int>`. The unspecialized-generic case (`extension Generic { ... }`, nested-in-generic types) was not documented. The compiler error is not in the skill.

## What Worked and What Didn't

**Worked**:

- Empirical verification before committing to the handoff's prescription. Attempting [SWIFT-TEST-002] on `Property Tests.swift` first and hitting the compile error within ~30s confirmed the path was blocked. Reverted with `git checkout` rather than fighting the tool or inferring a workaround that would have drifted from the skills.
- Skills-override-handoff escalation per CLAUDE.md's authoritative-documentation rule. Once the failure mode was empirically grounded, falling back to `[SWIFT-TEST-003]` was straightforward — the existing test files were already in that shape.
- Broadening the skill rather than narrow-patching. The original wording covered specializations only; the broader statement ("generic types — whether extended generically or at a concrete specialization") documents both failure modes in one rule and reframes the parallel namespace as "escape the generic context" (the single insight both failure modes reduce to).

**Didn't work**:

- Accepting the handoff's suite-shape prescription without verification. Handoffs that prescribe a specific target shape should be verified to compile before Phase 2 work lands — especially when the prescription touches a macro-driven surface where the compiler enforces constraints silently (at Phase 4 compile time, not at handoff authorship time). The ~5 minutes I spent re-reading `[SWIFT-TEST-003]` trying to reconcile the handoff could have been saved by a one-file compile check in Phase 1.

## Decisions

- **[SWIFT-TEST-003] broadened**: statement now covers generic types regardless of specialization, documents the `@section`-in-generic-context hard error alongside the silent-non-discovery case, and reframes the parallel-namespace pattern as escape-the-generic-context. Cross-references `[SWIFT-TEST-002]` and logs provenance.
- **Handoff prescription reversed**: all existing and new test files in `swift-property-primitives` use `[SWIFT-TEST-003]`. No file edits to the four existing files — they were already compliant. Two new smoke files (Typed, Consuming) and four new View.Typed-family files adopted the pattern.
- **Dual-accessor recipe for mutable view accessors**: `Property.View.Typed` extensions can have `mutating func` methods only when the accessor exposes `_modify` in addition to `mutating _read`. Non-obvious — `mutating _read` alone yields an immutable view at the caller, so `view.mutate(...)` fails with "cannot use mutating member on immutable value." The `mutating _read { yield ... } mutating _modify { var view = ...; yield &view }` double-accessor pattern is what the DocC article shows for `Property.View` and the same applies to `View.Typed`/`View.Typed.Valued`/`View.Typed.Valued.Valued`. Worth calling out in the `property-primitives` skill's canonical-usage section.

## Open Questions

- Whether `[SWIFT-TEST-003]` should be promoted ahead of `[SWIFT-TEST-002]` in the Swift Testing suite-shape decision tree, or whether the decision should explicitly route "is the type generic?" as the first branch. The current ordering (002 before 003) makes the hard-error case the fallback discovery rather than the expected path — for a primitives ecosystem where most types are generic, this inverts the common case.
- Whether there are other ecosystem packages currently in `[SWIFT-TEST-002]` extension shape on generic types that have been silently not-discovered (because the extension was on a specialization) or silently failed to compile (masked by broader build errors). A grep sweep for `extension.*<.*>` followed by `@Suite struct Test` would surface candidates.
- The DocC article for `Property.Consuming` documents the `_read` + `_modify` + `defer { restore() }` recipe, but the equivalent `_read` + `_modify` dual-accessor for `Property.View.Typed`-family types is not prominently documented. The fixture I added to Test Support (Slice `access` accessor) is effectively the reference implementation — whether to promote it into the View.Typed DocC article is scope for the documentation handoff, not this session.

## Follow-ups

- [ ] Consider reordering or adding a decision-tree preamble to the Suite Structure section of `testing-swiftlang/SKILL.md` that routes "generic type?" → `[SWIFT-TEST-003]` before `[SWIFT-TEST-002]`.
- [ ] Grep the ecosystem for `@Suite struct Test` inside `extension SomeGeneric<...>` or `extension SomeGeneric` where the outer type is generic — potential silent-discovery failures or hard-compile-error landmines.
- [ ] Document the `mutating _read` + `mutating _modify` dual-accessor recipe for `Property.View.Typed`-family types in the relevant DocC catalog (sibling documentation handoff scope).
- [x] `Performance` suite stubs in `swift-property-primitives` main test targets: dropped across all 10 files (`b1a7766`). Kept empty `Edge Case` / `Integration` stubs since those categories remain valid in main test targets. Broader question is now a separate follow-up: `[TEST-005]` mandates four categories, but if Performance belongs in a nested `Tests/Package.swift` per `[INST-TEST-*]`, then `[TEST-005]` should be revised to three categories for main test targets + Performance in the nested package. Needs ecosystem-wide decision.
- [ ] Review whether `[TEST-005]` should split: three mandatory categories in main test targets (Unit, Edge Case, Integration) + Performance (and Snapshot, once `#Tests` lands) in nested `Tests/Package.swift` per `[INST-TEST-*]`. Current `[TEST-005]` wording predates the nested-package split and leaves the Performance stub requirement ambiguous.

## Appendix: Commits

- `swift-institute/Skills`: `805d6f9` testing-swiftlang: [SWIFT-TEST-003] broaden to all generic types
- `swift-property-primitives`: `5ba78fe` test: split test target per source module (Phase 2)
- `swift-property-primitives`: `30a8825` test: relocate test files to per-module directories (Phase 3)
- `swift-property-primitives`: `0e96b3c` test: Typed + Consuming smoke coverage (Phase 5)
- `swift-property-primitives`: `6c2ac46` test: close View.Typed family + Consuming canonical pattern gaps

Test count: 16 (inherited) → 33 (final). Suite count: 21 → 51.
