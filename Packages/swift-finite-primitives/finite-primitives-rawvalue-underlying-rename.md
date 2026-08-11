# swift-finite-primitives: rawValue → underlying / Carrier.`Protocol` Migration

**Date**: 2026-05-03
**Tier**: 7b downstream migration (after ordinal/tagged/index/comparison/sequence)
**Upstream commits**:
- carrier-primitives `2b57aac` — `Carrier` → namespace; `Carrier.\`Protocol\``; `raw` → `underlying`
- tagged-primitives `46ded75` — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `.rawValue` → `.underlying`; `init(rawValue:)` → `init(_:)`; `init(__unchecked: ())` → `init(_unchecked:)`
- ordinal-primitives `e42df9f` — Ordinal own-field migrated; now `Carrier.\`Protocol\`` with `Underlying == UInt`

## Phase 1 — Design audit answers

### Q1. Own `public let rawValue` types? (Pre-authorized for rename.)

**None.** swift-finite-primitives declares no concrete `Carrier.\`Protocol\`` types of its own
that store a payload field. The canonical bounded-finite type is the typealias

```swift
extension Ordinal {
    public typealias Finite<let N: Int> = Tagged<Finite_Primitives_Core.Finite.Bound<N>, Ordinal>
}
```

`Finite.Bound<N>` is a phantom tag (zero-size, no rawValue). `Finite.Enumeration<Element>`
is a stateless RandomAccessCollection. `Finite.Capacity` is a marker protocol. `Finite.Enumerable`
is a protocol with a `var ordinal: Ordinal` requirement (NOT a stored rawValue).

**No own-field rename to apply.**

### Q2. Editorial public surface that could move to a sibling target / SLI?

Reviewed all public surface in `Sources/Finite Primitives Core/` and `Sources/Finite Primitives/`:

- Core: `Finite` namespace, `Finite.Bound<N>`, `Finite.Capacity`, `Finite.Enumerable`,
  `Finite.Enumeration<Element>`, `Ordinal.Finite<N>` typealias, `Index<E>.Bounded<N>`
  typealias, plus extensions on `Tagged where Tag == Finite.Bound<N>, RawValue == Ordinal`
  (successor / predecessor / offset / clamped / distance / complement / injected / projected /
  decomposed / composed) and `Tagged: Finite.Enumerable where Tag: Finite.Capacity, RawValue == Ordinal`.
- Umbrella: nine `Finite.Enumerable` conformances for sibling primitives (`Comparison`, `Polarity`,
  `Sign`, `Parity`, `Boundary`, `Bound`, `Endpoint`, `Gradient`, `Monotonicity`, `Ternary`) plus
  four `Algebra.Group` extensions (Bound, Boundary, Endpoint, Gradient) — all narrow,
  category-coherent.

Nothing here imports Foundation. Nothing depends on Swift Standard Library beyond what L1
already commits to (InlineArray, Span, Collection protocols). **No SLI carve-out warranted.**

The umbrella's `Algebra.Group+*.swift` files look candidate for a "Finite Algebra Integration"
sub-target purely on theme grounds, but they currently sit in the umbrella because they need
both `swift-algebra-group-primitives` and the per-type Finite-conformance files in the same
module. Modularization decision is independent of the underlying rename and is not in scope
here.

**No move recommended.**

### Q3. Three-consumer rule

The audit checks whether the package's public types serve at least three consumers. The
canonical exports here are:

- `Ordinal.Finite<N>` — used internally (Tagged extensions), in tests, and by downstream
  primitives that depend on bounded ordinal positions. This is THE finite-positions vocabulary
  for the ecosystem.
- `Finite.Enumerable` — adopted in this package by 11 sibling primitive types (Comparison,
  Polarity, Sign, Parity, Boundary, Bound, Endpoint, Gradient, Monotonicity, Ternary, plus
  Tagged where Tag: Capacity). Adopters per definition exist in higher-tier packages
  (any sum/enum-shaped finite domain).
- `Finite.Enumeration<Element>` — the zero-allocation iteration vehicle for Enumerable;
  used by every Enumerable consumer.
- `Index<E>.Bounded<N>` — bounded-index type for collection sites; not yet adopted in
  finite-primitives' own targets, but documented as the Ordinal.Finite-paired bridge.
  Verification of a third consumer is downstream (tier 8+ infrastructure not yet migrated).

The package's public surface is broad and spans multiple downstream consumers — the
three-consumer rule is comfortably satisfied for the core types.

**No deletion recommended.**

### Q4. Compound identifiers / `*Tag` suffixes / code-surface violations

Quick code-surface compliance scan:

- File names: all use `Type.Nested.swift` form. No compound identifiers.
- Type names: `Finite.Bound<N>`, `Finite.Capacity`, `Finite.Enumerable`, `Finite.Enumeration<E>`,
  `Ordinal.Finite<N>`. All correctly nested. No `Tag`-suffixed identifiers.
- Methods: `successor()`, `predecessor()`, `offset(by:)`, `clamped(offsetBy:)`, `distance(to:)`,
  `complement()`, `injected()`, `projected()`, `decomposed()`, `composed(row:column:)`,
  `capacity()`, `max()`. All single-word or properly labeled — no compound method names.
- Properties: `ordinal`, `count`, `position`, `startIndex`, `endIndex`, `_buffer` (internal).
  Compliant.
- One type per file: holds throughout.

**No code-surface violations found.**

## Verdict

**No escalation triggered.** The migration is purely mechanical:

1. `RawValue` → `Underlying` in extension constraints (where-clauses).
2. `.rawValue` → `.underlying` on Tagged values.
3. `init(__unchecked: (), value)` (single-arg form) → `init(_unchecked: value)`.
4. **Preserve** the protocol `Finite.Enumerable.init(__unchecked: Void, ordinal:)` — this
   is a *domain* signature on enumerable user types, NOT the Tagged unchecked init.
   Its call sites `T(__unchecked: (), ordinal: x)` retain their original shape.
5. **Preserve** `Tagged where Tag: ~Copyable` and `Tag == Finite.Bound<N>` constraints; the
   Tag generic position does not change name.
6. Rebuild against the new tagged signature `init(_unchecked: consuming Underlying)` — the
   project's own custom `init<let N: Int>(__unchecked value: Int) where Tag == Finite.Bound<N>,
   RawValue == Ordinal` keeps its label `__unchecked` (it's a different signature: takes an
   Int validated downstream). Only its internal call to the Tagged init must update.

Proceeding to Phase 2.
