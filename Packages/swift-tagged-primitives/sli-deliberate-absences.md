---
status: CATALOGUE
date: 2026-05-01
---

# SLI Deliberate Absences

Catalogue of stdlib protocols that `Tagged Primitives Standard Library Integration` (SLI) does NOT conform `Tagged` to, and the reason for each absence. Each absence has a paired research doc under `Research/principled-absence-*.md` and an empirical experiment under `Experiments/tagged-no-*/`.

The absences fall into three categories. Within each category, an entry classifies as **HARD** (a Swift-level or Foundation-axiom block; the absence is not actionable), **SOFT-shipped-in-SLI** (the conformance ships with caveats documented inline), or **SOFT-excluded-by-policy** (the conformance is excluded as a deliberate trade-off, not a structural blocker).

## Structural Swift-level blockers

| Missing conformance | Classification | Reason | Research |
|---|---|---|---|
| `RawRepresentable` | HARD | Not authorable on Swift 6.3.1 due to `~Escapable` non-awareness. | [principled-absence-rawrepresentable.md](principled-absence-rawrepresentable.md) |
| `@dynamicMemberLookup` | HARD | Type-declaration attribute, not retroactive on extensions. | [principled-absence-dynamicmemberlookup.md](principled-absence-dynamicmemberlookup.md) |

## Foundation axiom

| Missing conformance | Classification | Reason | Research |
|---|---|---|---|
| `LocalizedError` and `UUID` convenience inits | HARD | Would require importing Foundation; primitives layer is Foundation-free per `[PRIM-FOUND-001]`. | [principled-absence-foundation-protocols.md](principled-absence-foundation-protocols.md) |

## Policy trade-off

| Missing conformance | Classification | Reason | Research |
|---|---|---|---|
| `AdditiveArithmetic` / `Numeric` family | SOFT-excluded-by-policy | Operator-forwarding footgun on cross-domain arithmetic — the very property the fork's "operator non-forwarding is a feature" stance protects against. | [principled-absence-additivearithmetic-family.md](principled-absence-additivearithmetic-family.md) |
| `Strideable` | SOFT-excluded-by-policy | Excluded from SLI to keep the literal-conformance footgun dormant for SLI-only consumers. | [principled-absence-strideable.md](principled-absence-strideable.md) + [sli-literal-vs-strideable-tradeoff.md](sli-literal-vs-strideable-tradeoff.md) |
| `Identifiable` | SOFT-shipped-in-SLI | Forwards `id` to `underlying.id`; carries a documented identity-inversion trade-off. (Shipped with caveat; absent from this list as a "missing" conformance, listed here for catalogue completeness.) | [principled-absence-identifiable.md](principled-absence-identifiable.md) |
| `LosslessStringConvertible` | SOFT-shipped-in-SLI | `init?(_:)` parses, `description` from main's `CustomStringConvertible`; lossy-from-Tagged-perspective trade-off. (Shipped; listed here for completeness.) | [principled-absence-losslessstringconvertible.md](principled-absence-losslessstringconvertible.md) |
| `Sequence` and `Collection` | SOFT-shipped-in-SLI | `Sequence` forwards `makeIterator`; `Collection` forwards `startIndex` / `endIndex` / `subscript` / `index(after:)`. Wrapper-vs-content conflation trade-off documented. (Shipped.) | [principled-absence-sequence-collection.md](principled-absence-sequence-collection.md) |
| `Array` and `Dictionary` literals | SOFT-shipped-in-SLI via carve-out | Shipped under a documented `unsafeBitCast` carve-out (function-type reinterpretation between variadic and array forms only); marked with the `unsafe` expression keyword. | [principled-absence-array-dict-literal.md](principled-absence-array-dict-literal.md) |
| Niche / already-covered protocols (`CustomPlaygroundDisplayConvertible`, `CodingKeyRepresentable`, Decodable's double-try fallback) | SOFT-excluded-by-policy | Already covered by sibling conformances or genuinely niche; deliberate exclusion to keep SLI surface coherent. | [principled-absence-niche-protocols.md](principled-absence-niche-protocols.md) |

## Reading order

For first-time readers: start with the research doc whose conformance you expected and didn't find. Each `principled-absence-*.md` document carries the full reasoning, the empirical experiment URL under `Experiments/tagged-no-*/`, and the classification axis (HARD blocker, SOFT-shipped-in-SLI, or SOFT-excluded-by-policy).

The classification framework itself is documented in `tagged-literal-conformances.md`.
