# Equation Primitives — `RawValue` → `Underlying` rename design audit

**Date**: 2026-05-03
**Scope**: swift-equation-primitives only.
**Trigger**: Tier 1.5a cascade following swift-tagged-primitives `46ded75`
(`Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `.rawValue` → `.underlying`)
and swift-carrier-primitives `2b57aac` (`Carrier` bare-namespace enum;
protocol moved to `Carrier.\`Protocol\``).

## Inventory of public surface

| File | Public surface | Touches rename targets? |
| --- | --- | --- |
| `Sources/Equation Primitives Core/Equation.swift` | `public enum Equation` namespace | No |
| `Sources/Equation Primitives Core/Equation.Protocol.swift` | `Equation.\`Protocol\``; default `!=` | No |
| `Sources/Equation Primitives Core/exports.swift` | `@_exported public import Property_Primitives` | No |
| `Sources/Equation Primitives Standard Library Integration/Equation.Protocol+Swift.*.swift` | `Equation.\`Protocol\`` conformances on stdlib types (Int*, UInt*, Bool, String, Character, Double, Float, Array, ArraySlice, ContiguousArray, CollectionOfOne, Dictionary, EmptyCollection, KeyValuePairs, Optional, PartialRange*, Range, ReversedCollection, Result, Set, Unsafe*Pointer, Unsafe*BufferPointer) | No |
| `Sources/Equation Primitives/Equation.Protocol+Identity.Tagged.swift` | `Tagged: Equation.\`Protocol\`` conditional conformance + `==` | **Yes** — line 6 (`RawValue: ~Copyable`) and line 17 (`lhs.rawValue == rhs.rawValue`) |
| `Sources/Equation Primitives/exports.swift` | umbrella re-exports | No |

## Q1 — Own `public let rawValue` types?

**No.** This package declares zero stored properties. Its public surface is one
namespace enum (`Equation`), one protocol (`Equation.\`Protocol\``), and a set of
`Equation.\`Protocol\`` conformance extensions. There is no `public let rawValue`
to rename in this package; the rename only touches code that **consumes**
`Tagged.rawValue` / the `Tagged.RawValue` associated type.

Pre-authorized branch is therefore vacuous here — nothing to rename internally;
only the consumption pattern at the Tagged conformance site changes.

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**No non-trivial recommendation.**

The editorial layout is already correctly partitioned:

- `Equation Primitives Core` — bare protocol, no stdlib coupling
- `Equation Primitives Standard Library Integration` — stdlib bridges
  (Int, Bool, Array, Dictionary, Range, Result, Optional, Unsafe pointers, …)
- `Equation Primitives` — umbrella re-exporting Core + SLI, plus the
  `Tagged: Equation.\`Protocol\`` conformance.

The Tagged conformance lives in the umbrella `Equation Primitives` target rather
than in a dedicated `Equation Primitives Tagged Integration` target. This is
**defensible** — Tagged is a Property-layer primitive, not a stdlib type, and
the umbrella's whole point is to fold in primitives-side integrations. The
alternative (a dedicated Tagged-integration sibling target) would add scaffolding
for a single 19-line file. Not worth churning during a mechanical-rename pass.
Logged here for future revisit only if the umbrella accumulates more
Property-layer integrations.

## Q3 — Three-consumer rule

The package's public API is the protocol itself plus conformances. There are
no public `init`s, accessors, or methods owned by this package beyond:

- `Equation.\`Protocol\`.==` (the requirement; satisfied by every conformer)
- `Equation.\`Protocol\`.!=` (defaulted via `!(lhs == rhs)`)

Both are protocol surface, not API entry-points the three-consumer rule attaches
to. The conformance extensions all delegate to the underlying type's existing
`==` (stdlib `Equatable` or, for Tagged, the underlying value's `==`). No
new accessors are introduced by the rename cycle, so the three-consumer
question is **vacuous** for this package.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**None observed.** Spot-check:

- `Equation` is a namespace enum (matches [API-NAME-001]).
- `Equation.\`Protocol\`` uses the `\`Protocol\`` capability-protocol idiom
  consistent with the namespace-canonical-protocol convention.
- All conformance files follow the `Equation.Protocol+Domain.Type.swift`
  filename pattern (one type per file at the conceptual level — each file adds
  exactly one extension on one external type, satisfying the spirit of
  [API-IMPL-005]).
- No `*Tag`-suffixed phantom types are declared by this package.
- No compound identifiers (e.g. `EquationProtocol`, `RawValueEquation`).
- The single migration site uses `RawValue` and `lhs.rawValue` only because
  those were the upstream Tagged spellings; mechanical rename converts them
  to `Underlying` / `lhs.underlying` and the file is otherwise compliant.

Nothing for the rename cycle to clean up beyond the mechanical substitution.

## Verdict

**Phase 1 GREEN — proceed mechanically. No escalation.**

- Q1: vacuous (no own `rawValue`).
- Q2: trivial (current target layout is correct; Tagged-integration target
  split deferred as not-worth-it).
- Q3: vacuous (no `init`/accessor/method API surface beyond protocol
  requirements).
- Q4: clean (no compound identifiers, no `*Tag` suffixes, no other code-surface
  violations).

Single migration site:
`Sources/Equation Primitives/Equation.Protocol+Identity.Tagged.swift`
lines 6, 12 (doc comment), 17.

Mechanical edits:
- `RawValue: ~Copyable & Equation.\`Protocol\`` → `Underlying: ~Copyable & Equation.\`Protocol\``
- `lhs.rawValue == rhs.rawValue` → `lhs.underlying == rhs.underlying`
- doc comment on line 12 (`when RawValue conforms to both`) →
  `when Underlying conforms to both`

No `Carrier` references in this package, so the `Carrier.\`Protocol\`` half of
the cascade does not apply here.
