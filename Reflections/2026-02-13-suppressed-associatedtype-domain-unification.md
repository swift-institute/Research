---
date: 2026-02-13
session_objective: Determine if SuppressedAssociatedTypes unblocks Phase 2 protocol Domain unification, and if so, unify the affine Vector-Cardinal comparisons
packages:
  - swift-affine-primitives
  - swift-vector-primitives
  - swift-ordinal-primitives
  - swift-cardinal-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-003a] domain-crossing before operations — .retag() first, then operate
  - type: doc_improvement
    target: protocol-abstraction-for-phantom-typed-wrappers.md
    description: Update DECISION → IMPLEMENTED, add Phase 2 completion changelog entry
  - type: research_topic
    target: affine-operator-unification-completeness.md
    description: Should remaining Tagged+Affine operators be unified via Domain?
---

# SuppressedAssociatedTypes Unblocks Phase 2 Domain Unification

## What Happened

The session started from the observation that ordinal-primitives, cardinal-primitives, and affine-primitives each have separate `.Protocol` protocols — a design documented in `protocol-abstraction-for-phantom-typed-wrappers.md` (DECISION, v1.3.0). That research established a two-phase plan:

- **Phase 1** (implemented 2026-02-04): Per-type protocols without `Domain`, unifying 17/31 operators via protocol generics.
- **Phase 2** (blocked): Add `associatedtype Domain: ~Copyable` to enable `where O.Domain == C.Domain` cross-type operators, completing 31/31 unification.

Phase 2 was blocked by the `noncopyable-associatedtype-domain` experiment (2026-02-04), which REFUTED `associatedtype Domain: ~Copyable` — the compiler emitted "cannot suppress 'Copyable' requirement of an associated type."

The critical discovery: that experiment never enabled `.enableExperimentalFeature("SuppressedAssociatedTypes")`. Eight days later (2026-02-12), the `suppressed-associated-types` experiment in sequence-primitives confirmed that `associatedtype Element: ~Copyable` compiles with the flag — but nobody connected this back to the Domain blocker.

We created `suppressed-associatedtype-domain` experiment (6 variants, all CONFIRMED) proving the flag unblocks the entire Phase 2 design. Then discovered that ordinal-primitives and cardinal-primitives had already completed Phase 2 — `SuppressedAssociatedTypes` was enabled, `Domain: ~Copyable` was present, cross-type operators used `where O.Domain == C.Domain`.

Only affine-primitives remained at Phase 1. We:

1. Enabled `SuppressedAssociatedTypes` in affine-primitives Package.swift
2. Added `associatedtype Domain: ~Copyable` to `Affine.Discrete.Vector.Protocol`
3. Set `Domain = Never` on bare Vector, `Domain = Tag` on Tagged conformance
4. Replaced 8 bare + 8 tagged Vector-Cardinal comparisons with 8 unified generic comparisons using `where V.Domain == C.Domain`
5. Fixed 2 downstream call sites in vector-primitives where `.vector` extraction crossed domain boundaries

## What Worked and What Didn't

**Worked well:**

- The experiment-first approach caught the flag gap cleanly. Six variants, all confirmed in one pass.
- The unified operators compiled and passed 130 downstream tests on first attempt (after fixing the domain-crossing call sites).
- The `retag()` fix for the vector-primitives call sites was cleaner than any rawValue-level workaround.

**Didn't work initially:**

- First build attempt after unification failed with linker errors (stale `.build` cache referencing old witness tables). Wasted a cycle before realizing a clean build was needed.
- The downstream vector-primitives call sites (`offset.vector < count`) broke because they relied on the old domain-agnostic bare comparison. This was a legitimate domain-safety improvement, not a regression — but it required understanding the call site semantics to fix correctly.

**Confidence was low on:**

- Whether the unified operators would cause ambiguity with existing same-type operators. They didn't — `@_disfavoredOverload` on the cross-type operators resolved cleanly.

## Patterns and Root Causes

**The feature-flag awareness gap**: The `noncopyable-associatedtype-domain` experiment (2026-02-04) and the `suppressed-associated-types` experiment (2026-02-12) were done in different packages with different objectives. Neither referenced the other. The connection — that the same flag resolves both problems — went unnoticed for 9 days. This suggests that experiment results should cross-reference related blockers explicitly.

**Domain-crossing is the real API surface**: The vector-primitives fix revealed that `.vector` extraction was being used as an implicit domain escape hatch. The old bare operators (`Affine.Discrete.Vector < some Cardinal.Protocol`) were domain-agnostic by accident, not by design. When Domain enforcement arrived, the escape hatch broke. The correct pattern — `.retag()` first, then operate in the target domain — was already established in the same file (lines 34-35) but not applied to the offset subscripts. This is the "convert at the boundary, operate in-domain" principle that typed arithmetic enforces.

**Phase 2 was already 90% done**: Ordinal and cardinal primitives had silently completed Phase 2. Only affine remained. This suggests the phased approach worked well — packages could adopt Domain independently as the feature flag became available. The research document's phase boundary was at the package level, not the ecosystem level.

## Action Items

- [ ] **[skill]** implementation: Add guidance for domain-crossing patterns — `.retag()` before bounds checks, not `.rawValue` extraction. The pattern "convert to target domain first, then operate" is a corollary of [IMPL-003] but not explicitly stated for the bounds-check case.
- [ ] **[doc]** protocol-abstraction-for-phantom-typed-wrappers.md: Update status from DECISION to IMPLEMENTED. Phase 2 is complete across all three protocol types. Remove "blocked" language, add implementation dates, reference the `suppressed-associatedtype-domain` experiment.
- [ ] **[research]** Should the remaining Tagged+Affine.swift operators (Ordinal-Ordinal->Vector, Tagged Ordinal-Tagged Vector) also be unified via Domain + companion types, or is the current split between bare-return and tagged-return intentional?
