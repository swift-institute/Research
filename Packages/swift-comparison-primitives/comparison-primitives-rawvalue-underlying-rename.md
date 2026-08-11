# Comparison Primitives — `RawValue` → `Underlying` rename design audit

**Date**: 2026-05-03
**Scope**: swift-comparison-primitives only.
**Trigger**: Tier 1.5b cascade following swift-tagged-primitives `46ded75`
(`Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `.rawValue` → `.underlying`)
and swift-carrier-primitives `2b57aac` (`Carrier` bare-namespace enum;
protocol moved to `Carrier.\`Protocol\``). Sibling-tier 1.5a
(swift-equation-primitives `065bae3`) is the immediate upstream.

## Inventory of public surface

| File | Public surface | Touches rename targets? |
| --- | --- | --- |
| `Sources/Comparison Primitives Core/Comparison.swift` | `public enum Comparison` (three-way result, `Sendable, Hashable, CaseIterable, Codable`) | No |
| `Sources/Comparison Primitives Core/Comparison.Protocol.swift` | `Comparison.\`Protocol\``; defaults `<=`, `>`, `>=` | No |
| `Sources/Comparison Primitives Core/Comparison.Clamp.swift` | `Comparison.Clamp` namespace enum (Property.View tag) | No |
| `Sources/Comparison Primitives Core/Comparison.Compare.swift` | `Comparison.Compare` namespace enum (Property.View tag) | No |
| `Sources/Comparison Primitives Core/Comparison.Clamp+Property.View.swift` | `Property.View<_, Comparison.Clamp>` accessors | No |
| `Sources/Comparison Primitives Core/Comparison.Compare+Property.View.swift` | `Property.View<_, Comparison.Compare>` accessors | No |
| `Sources/Comparison Primitives Core/Comparison.Protocol+Property.View.swift` | `.compare` / `.clamp` Property.View entry points | No |
| `Sources/Comparison Primitives Core/Comparison+Comparable.swift` | bridging from `Swift.Comparable` to `Comparison` | No |
| `Sources/Comparison Primitives Core/Comparison+BooleanProperties.swift` | `.isLess`, `.isEqual`, … boolean accessors | No |
| `Sources/Comparison Primitives Core/Comparison+Chaining.swift` | `Comparison.Result` chaining helpers | No |
| `Sources/Comparison Primitives Core/Comparison+Reversal.swift` | reversal helper | No |
| `Sources/Comparison Primitives Standard Library Integration/Comparison+Swift.Comparable.swift` | stdlib bridging | No |
| `Sources/Comparison Primitives Standard Library Integration/Comparison.Clamp+Swift.Comparable.swift` | clamp surface for `Swift.Comparable` | No |
| `Sources/Comparison Primitives Standard Library Integration/Comparison.Compare+Swift.Comparable.swift` | compare surface for `Swift.Comparable` | No |
| `Sources/Comparison Primitives Standard Library Integration/Comparison.Protocol+Swift.*.swift` | `Comparison.\`Protocol\`` conformances on stdlib types (Array, ArraySlice, ContiguousArray, CollectionOfOne, EmptyCollection, KeyValuePairs, Optional, PartialRange*, Range, ReversedCollection, Unsafe*Pointer, Unsafe*BufferPointer) | No |
| `Sources/Comparison Primitives/Comparison.Protocol+Identity.Tagged.swift` | `Tagged: Comparison.\`Protocol\`` conditional conformance + `<` | **Yes** — line 6 (`RawValue: ~Copyable`), line 12 (doc comment), line 17 (`lhs.rawValue < rhs.rawValue`) |
| `Sources/Comparison Primitives/exports.swift` | umbrella re-exports | No |

## Q1 — Own `public let rawValue` types?

**No.** This package declares zero stored properties.

`grep -n 'public let rawValue\|public var rawValue\|public init(rawValue\|public init(_unchecked' Sources/`
returns nothing. The package's public surface is:
- the `Comparison` three-way result enum;
- the `Comparison.\`Protocol\`` capability protocol;
- the `Comparison.Clamp` and `Comparison.Compare` Property.View tag enums (no
  cases, no payload);
- conformance extensions on stdlib types and on `Tagged`.

The pre-authorized "own rawValue" rename is therefore **vacuous** — nothing to
rename internally. Only the **consumption** pattern at the Tagged conformance
site changes (`Tagged.RawValue` associated type → `Underlying`,
`tagged.rawValue` → `tagged.underlying`).

## Q2 — Editorial public surface that could move to a sibling target / SLI?

**No non-trivial recommendation.**

The editorial partition is already correct and matches the equation-primitives
pattern:

- `Comparison Primitives Core` — bare protocol, three-way `Comparison` enum,
  Property.View tags (`Clamp`, `Compare`), and the Property.View accessor
  surfaces. No stdlib coupling beyond `Bool` (which is unavoidable as `<` returns
  `Bool`).
- `Comparison Primitives Standard Library Integration` — every conformance on
  stdlib types (Array, Range, Optional, Unsafe pointers, …) and the
  `Swift.Comparable`-side bridging (`Comparison+Swift.Comparable.swift`,
  `Comparison.Clamp+Swift.Comparable.swift`, `Comparison.Compare+Swift.Comparable.swift`).
- `Comparison Primitives` — umbrella re-exporting Core + SLI, plus the single
  `Tagged: Comparison.\`Protocol\`` conformance.

The Tagged conformance lives in the umbrella target rather than in a dedicated
`Comparison Primitives Tagged Integration` target. This is **defensible** —
Tagged is a Property-layer primitive (not stdlib), and the umbrella's whole
point is to fold in primitives-side integrations. The alternative would add
scaffolding for a single 19-line file. Not worth churning during a
mechanical-rename pass. Logged here only for future revisit if the umbrella
accumulates more Property-layer integrations (mirrors the equation-primitives
verdict).

## Q3 — Three-consumer rule

The package's public API consists of:

- the `Comparison.\`Protocol\``.`<` requirement (satisfied by every conformer);
- defaulted `<=`, `>`, `>=` on `Comparison.\`Protocol\``;
- the `Comparison` three-way result enum (used by every consumer of `.compare.to`);
- the Property.View accessor surfaces under `.compare` and `.clamp`
  (`isLess(than:)`, `isEqual(to:)`, `between(_:and:)`, `above(_:)`, `below(_:)`,
  …) — these are the user-facing fluent API.

These are all **infrastructure** API consumed by the broader ecosystem — the
ordering protocol is the canonical replacement for `Swift.Comparable` on
`~Copyable` types, and the `.compare`/`.clamp` Property.View accessors are
designed to be used wherever ordering is needed. There is no
narrowly-purposed init/accessor/method introduced by the rename cycle that
would fail a three-consumer test. The rename only touches **consumption** of
`Tagged`'s associated type and accessor.

The three-consumer question is therefore **vacuous** for this rename pass.

## Q4 — Compound identifiers / `*Tag` suffixes / code-surface violations

**None observed.** Spot-check:

- `Comparison` is a namespace enum (matches [API-NAME-001]).
- `Comparison.\`Protocol\`` uses the `\`Protocol\`` capability-protocol idiom.
- `Comparison.Clamp` and `Comparison.Compare` are namespace enums, **not**
  `*Tag`-suffixed (good — the doc comments call them "tag types" but the
  identifiers themselves are concept names per the no-`*Tag`-suffix rule).
- All conformance files follow the `Comparison.Protocol+Domain.Type.swift`
  filename pattern (one extension per file).
- No compound identifiers (e.g. `ComparisonProtocol`, `ClampProperty`,
  `CompareTag`).
- The single migration site uses `RawValue` and `lhs.rawValue` only because
  those were the upstream Tagged spellings; mechanical rename converts them
  to `Underlying` / `lhs.underlying` and the file is otherwise compliant.

Nothing for the rename cycle to clean up beyond the mechanical substitution.

## Verdict

**Phase 1 GREEN — proceed mechanically. No escalation.**

- Q1: vacuous (no own `rawValue`).
- Q2: trivial (target layout is correct; Tagged-integration target split
  deferred as not-worth-it; mirrors equation-primitives 1.5a verdict).
- Q3: vacuous (no `init`/accessor/method API surface introduced by the rename;
  protocol surface and Property.View accessors are infrastructure).
- Q4: clean (no compound identifiers, no `*Tag` suffixes, no other
  code-surface violations).

Single migration site:
`Sources/Comparison Primitives/Comparison.Protocol+Identity.Tagged.swift`
lines 6, 12 (doc comment), 17.

Mechanical edits:
- `RawValue: ~Copyable & Comparison.\`Protocol\`` → `Underlying: ~Copyable & Comparison.\`Protocol\``
- `lhs.rawValue < rhs.rawValue` → `lhs.underlying < rhs.underlying`
- doc comment on line 12 (`when RawValue conforms to both`) →
  `when Underlying conforms to both`

No `Carrier` references in this package, so the `Carrier.\`Protocol\`` half of
the cascade does not apply here.
