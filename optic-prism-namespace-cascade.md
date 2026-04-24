# Optic.Prism Namespace Cascade

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | Ecosystem-wide |
| Status | IN_PROGRESS |
| Provenance | 2026-04-22-iso9945-signal-information-cycle2-beta-prime-revision.md; 2026-04-22-cycle-2-close-beta-prime-and-c-representability.md |

## Context

`Tagged` types in `swift-identity-primitives` ship a synthesized `Optic.Prism<Enum, Part>` accessor surface on each case. The synthesized `.caseName` members collide with pattern-match syntax at consumer call sites when the consumer `public import`s a Tagged-bearing primitive transitively.

Observed at `iso-9945 Configuration.swift:85` during Cycle 2 — a consumer that matched `case .caseName(_):` on a locally-declared enum hit an overload ambiguity because `Tagged`'s prism accessor for the imported module's matching case name was in scope.

## Question

Which consumer modules in the ecosystem are at risk? Is the correct fix a naming-discipline rule on Tagged-derived accessors, an access-level change (`@_spi` the prism namespace), a macro-output adjustment, or a call-site disambiguation convention (`case Module.Type.caseName:`)?

## Analysis

This document is the consultation artifact for the investigation. Fill in:

1. **Inventory**: every module that `public import`s a Tagged-bearing primitive (`swift-kernel-primitives/Kernel.Memory.Address`, `swift-memory-primitives/Memory.Address`, others). Use:

   ```bash
   grep -rn "public import.*Tagged\|public import.*swift-memory-primitives\|public import.*swift-kernel-primitives" Sources/
   ```

2. **Collision-risk sites**: enums within those modules that declare cases whose names match Tagged-synthesized prism accessors. Pattern:

   ```bash
   grep -nE "^[[:space:]]*case +[a-z]" <at-risk-module>/Sources/
   ```

3. **Workaround patterns**: classify each site's resolution — wildcard pattern (`case .caseName(_):`), demoted `internal import`, fully-qualified `case Module.Type.caseName:`, or rename the conflicting case.

4. **Criterion**: when is a consumer at risk? Rule-of-thumb from the first observed case: any consumer that declares an enum AND transitively imports a Tagged-bearing module with a matching case name.

## Outcome (pending)

Choose one:

- A. Naming-discipline rule at the Tagged macro site (prism accessors named `.caseNamePrism` or similar).
- B. Access-level change — `@_spi` the Optic.Prism namespace.
- C. Call-site convention — consumer must fully-qualify case matches in affected sites.
- D. Accept-and-document — no upstream change; the workaround pattern is the answer.

## References

- Reflections: 2026-04-22-cycle-2-close-beta-prime-and-c-representability.md, 2026-04-22-iso9945-signal-information-cycle2-beta-prime-revision.md
- `swift-identity-primitives/Research/tagged-literal-conformances-fresh-perspective.md`
