# SLI — Span family (`Span`, `MutableSpan`, `RawSpan`, `MutableRawSpan`): Adopt (revised 2026-04-25, v1.2.0)

<!--
---
version: 1.2.0
last_updated: 2026-04-25
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

Swift 6 introduces the span family (SE-0447 `Span<Element>`, SE-0467 `MutableSpan<Element>`, plus `RawSpan` / `MutableRawSpan`) as `~Escapable` contiguous-memory views. Copyable, `~Escapable`. These fit Carrier's Q3 quadrant (Copyable × `~Escapable`). Should any conform to `Carrier`?

## Analysis

### Structural match

`Span<Element>` is Copyable and `~Escapable`. The generic self-carrier form is viable:

```swift
extension Span: Carrier {
    public typealias Underlying = Span<Element>
    // The default extension provides getter + init, BUT the default
    // is written for Escapable types (omits @_lifetime annotations).
    // For ~Escapable Self, the default's `_read { yield self }` may or
    // may not pass the @_lifetime(borrow self) requirement on the
    // protocol; needs verification.
}
```

### Semantic fit

Span IS a value carrier in a defensible sense — `Span<Int>` carries a `Span<Int>` (itself). The `~Escapable` shape matches Carrier's Q3 quadrant structurally. Form-D generic algorithms (`describe<C: Carrier & ~Copyable & ~Escapable>(_ c: borrowing C)`) would work on Span.

### Why skip

1. **Verification cost.** The trivial-self-carrier default extension uses `_read { yield self }` without `@_lifetime(borrow self)`. Whether this satisfies the protocol's `@_lifetime(borrow self) borrowing get` requirement for `~Escapable` Self is unverified; it might compile but produce wrong lifetime semantics at consumer call sites. Would need bespoke conformance with explicit `@_lifetime` annotations per span type — not a one-liner.

2. **Generic type wrinkle.** Span takes a `Pointee: ~Copyable & ~Escapable` parameter (analogous to Array's Element). Parametric Carrier shapes ("Span of a Carrier Pointee") have the same Array-family complications (see `sli-array.md`).

3. **Conformance would require explicit bodies.** The trivial-self-carrier default likely can't cover Span safely; each Span variant would need its own extension with `@_lifetime` annotations. Four types × explicit bodies is higher effort than the Copyable SLI conformances (one-liner each).

4. **Single-conformance lock.** Shipping `Span<Element>: Carrier` centrally forbids consumer-declared parametric shapes for Span, which is especially costly for a type as new and evolving as Span.

### Could-it-be-done verdict

| Form | Viable? | Cost |
|------|---------|------|
| Self-carrier with default extension | Unverified; may fail `@_lifetime` requirement | Needs testing |
| Self-carrier with explicit `@_lifetime` | Yes | 4 explicit bodies, not one-liners |
| Parametric (Element-unwrap) | Yes, non-trivially | Array-family complications |

## Empirical update (2026-04-25)

`Experiments/span-carrier-conformance/` (V1–V4, CONFIRMED) settles concerns #1 and #3 with sharper findings than this document anticipated:

- **Concern #1 was right that the default doesn't apply, but for a different reason.** V1 REFUTED bare `extension Span: Carrier { typealias Underlying = Self }`. The failure isn't a `@_lifetime` mismatch on the witness body; it's that `extension Carrier where Underlying == Self` carries Self's default `Escapable` constraint and does not propagate `~Escapable`. The witness candidates are excluded from consideration entirely. Diagnostic: *"candidate would match if 'Span<Element>' conformed to 'Escapable'"*.
- **Concern #3 was correct.** V2 CONFIRMED that explicit witnesses work — `@_lifetime(borrow self) _read { yield self }` plus `@_lifetime(copy underlying) init(_ underlying: consuming Span<Element>) { self = underlying }`. Side finding: `borrowing get { self }` does NOT work for `~Escapable` Self (treated as a consume); `_read { yield self }` is required.
- **Cross-module + release pass.** V3 (cross-module generic dispatch) and V4 (release build) both CONFIRMED. Form-D generic algorithms compile and dispatch through Span correctly. A generic algorithm returning `C.Underlying` as a function result MUST add `where C.Underlying: Copyable` (the protocol's `Underlying: ~Copyable & ~Escapable` would otherwise reject the return as a `copy` of a noncopyable). Span is Copyable, so use sites for Span-of-T satisfy the constraint.

Concerns #2 (parametric "Span of a Carrier Pointee") and #4 (single-conformance lock for an evolving stdlib type) are NOT settled by the experiment; they remain considerations against parametric shapes and against premature centralization, but they do not block the trivial-self conformance that this document originally rejected.

## Outcome

**Status (revised 2026-04-25, v1.2.0)**: DECISION — adopt trivial-self conformance for the four span types in 0.1.x SLI. With the Q3 default extension landed in the same session (per `Experiments/relax-trivial-self-default/`), each conformance is now a one-line typealias.

**Original status (2026-04-24)**: SKIP. Superseded twice:
- v1.1.0 (2026-04-25): empirical result from `Experiments/span-carrier-conformance/` showed explicit ~5-line witnesses are viable. Adopted with explicit witnesses.
- v1.2.0 (2026-04-25): empirical result from `Experiments/relax-trivial-self-default/` showed sibling default extensions can cover `~Escapable` Self. Conformances reduced to one-liners.

**Conformance shape (per Span variant, v1.2.0)**:

```swift
extension Span: Carrier {
    public typealias Underlying = Span<Element>
    // `underlying` and `init(_:)` satisfied by the default
    // `extension Carrier where Underlying == Self, Self: ~Escapable`.
}
```

`MutableSpan`, `RawSpan`, `MutableRawSpan` follow the same shape with their own type substituted for `Span<Element>`.

**Open item closed (2026-04-25)**: the v1.1.0 "Open" question — whether the default extension can be loosened — was answered empirically. Three sibling default extensions now cover Q2 / Q3 / Q4 in addition to the original Q1, with quadrant-appropriate `@_lifetime` annotations.

## References

- Swift stdlib `Span<Element>` (SE-0447), `MutableSpan<Element>` (SE-0467), `RawSpan`, `MutableRawSpan`.
- `Research/Carrier Primitives Vision.md` (formerly `capability-lift-pattern.md` §V5b, V5c, consolidated 2026-04-29) — `~Copyable` and `~Escapable` quadrant considerations.
- `Sources/Carrier Primitives/Carrier where Underlying == Self, Self ~Escapable.swift` — the Q3 default extension covering Span family.
- `Experiments/span-carrier-conformance/` — empirical verification of the explicit-witness shape (V1 REFUTED, V2/V3/V4 CONFIRMED, 2026-04-25).
- `Experiments/relax-trivial-self-default/` — empirical verification of the sibling default extensions (V1/V2/V3 CONFIRMED, 2026-04-25).
