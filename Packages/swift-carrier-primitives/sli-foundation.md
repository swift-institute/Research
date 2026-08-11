# SLI — Foundation types (`Date`, `URL`, `Data`, `TimeInterval`, `UUID`, and all others): Skip (hard skip)

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

Foundation provides a large number of value-type wrappers: `Date`, `URL`, `Data`, `TimeInterval`, `UUID`, `URLRequest`, `IndexPath`, `Measurement`, `DateComponents`, and many more. Conceptually several fit Carrier's abstraction (Date wraps a TimeInterval; URL wraps a String; UUID wraps 16 bytes). Should any conform to `Carrier` in an SLI-adjacent target?

## Analysis

### The `[PRIM-FOUND-001]` blocker

The primitives layer is Foundation-independent by absolute rule:

> `[PRIM-FOUND-001]` No Foundation Imports — Primitives packages MUST NOT import Foundation or use Foundation types. This is absolute.

Any target in `swift-carrier-primitives` — including Standard Library Integration — is bound by this rule. An `import Foundation` in any carrier-primitives target would disqualify the entire package from the primitives layer.

### Consequence

Foundation types cannot appear in any source file of carrier-primitives. Conformance declarations for `Date: Carrier`, `URL: Carrier`, etc. are categorically ruled out here.

### Where Foundation conformances could live

In a separate package at a different layer:

- **Foundations layer** (e.g., a hypothetical `swift-foundation-carrier-integration` package): permits Foundation imports and can declare Foundation-type Carrier conformances. But this package does not exist in the ecosystem and would require deliberate creation, not a side-effect of carrier-primitives shipping.
- **Consumer packages**: any package at Foundations or higher that uses both Foundation and Carrier can declare the conformances it needs directly.

The single-conformance rule means exactly ONE place in the build graph can own `Date: Carrier`, `URL: Carrier`, etc. Without a dedicated Foundation-integration package, centralization goes to the first-to-declare — a coordination hazard consumers would navigate on their own terms.

### Could-it-be-done verdict

| Option | Viable? |
|--------|---------|
| In carrier-primitives SLI | Categorically no — `[PRIM-FOUND-001]` forbids Foundation imports |
| In a higher-layer package | Possible, but out of scope for carrier-primitives 0.1.0 FINAL |

## Outcome

**Status**: DECISION — hard skip from carrier-primitives SLI (and from any other carrier-primitives target).

**Rationale**: `[PRIM-FOUND-001]` is absolute. Foundation-type Carrier conformances — if wanted — belong in a higher-layer package that imports Foundation, not in any carrier-primitives target.

This decision applies to the complete Foundation type surface: `Date`, `URL`, `Data`, `TimeInterval`, `UUID`, `IndexPath`, `Measurement`, `DateComponents`, `DateInterval`, `PersonNameComponents`, `CharacterSet`, `IndexSet`, `NSRange` (bridged), `Decimal`, `NSString` (bridged), and the rest.

## References

- `[PRIM-FOUND-001]` primitives convention (from the `primitives` skill).
- Foundation itself (Apple's framework).
