# Witness.Protocol Sendable Requirement

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: SUPERSEDED
superseded_by: witness-ownership-integration.md
tier: 1
trigger: Parser.Machine.Compile.Witness is a legitimate non-Sendable witness excluded by Witness.Protocol's Sendable constraint
---
-->

> **SUPERSEDED** (2026-04-02) by [witness-ownership-integration.md](witness-ownership-integration.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

During ecosystem-wide adoption of `Witness.Protocol` conformance (see `witnesses-ecosystem-adoption-audit.md`), `Parser.Machine.Compile.Witness<P>` was identified as a legitimate closure-struct witness that cannot conform because `Witness.Protocol` requires `Sendable`.

`Parser.Machine.Compile.Witness` wraps a single `_compile` closure that transforms a parser into a Machine expression. The closure operates synchronously on a single thread via `inout Builder`. Neither the closure nor the struct cross isolation boundaries. Making it `@Sendable` would impose a meaningless constraint that propagates to all parser types.

### Current definition

```swift
// swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift
extension Witness {
    public protocol `Protocol`: Sendable {}
}
```

## Question

Should `Witness.Protocol` require `Sendable`?

## Analysis

### Option A: Keep `Sendable` requirement

**Description**: `Witness.Protocol` remains `: Sendable`. Non-Sendable witnesses cannot conform.

**Advantages**:
- Guarantees every `Witness.Protocol` type can be stored in `Witness.Values`, passed across isolation, used with `Witness.Key`
- No change needed

**Disadvantages**:
- Excludes legitimate witnesses like `Parser.Machine.Compile.Witness`
- Conflates two orthogonal concerns: "this is a closure-struct witness" (semantic marker) vs "this can cross isolation domains" (Sendable)
- Forces types to add `@Sendable` to closures that don't cross isolation boundaries

### Option B: Remove `Sendable` requirement

**Description**: `Witness.Protocol` becomes a pure semantic marker. `Sendable` is required where it's actually needed (`Witness.Key`, `Witness.Values`, `Witness.Context`).

```swift
extension Witness {
    public protocol `Protocol` {}
}
```

**Advantages**:
- Correctly separates concerns: "is a witness" vs "is sendable"
- Enables conformance for non-Sendable witnesses (`Parser.Machine.Compile.Witness`, future non-Sendable closure-struct types)
- Aligns with the nonsending adoption audit principle: Sendable should be required only where isolation-domain crossing actually occurs
- All existing conformances already declare `: Sendable` explicitly — zero breakage

**Disadvantages**:
- A `Witness.Protocol` type is no longer guaranteed to be usable with `Witness.Key`/`Witness.Context` — but this was always the case anyway (Key requires its own conformance)

### Comparison

| Criterion | Option A (keep) | Option B (remove) |
|---|---|---|
| Semantic accuracy | Overly restrictive | Correct |
| Existing conformance breakage | None | None (all already `: Sendable`) |
| Enables Parser.Machine.Compile.Witness | No | Yes |
| Future non-Sendable witnesses | Excluded | Included |
| Witness.Key/Context safety | Guaranteed by Protocol | Guaranteed by Key's own `: Sendable` constraint |
| Nonsending alignment | Conflates concerns | Separates correctly |

### Impact analysis

**`Witness.Key`** — already requires `Sendable` independently through `__WitnessKeyTest: Sendable`. Does NOT inherit from `Witness.Protocol`. Unaffected.

**`Witness.Context` / `Witness.Values`** — stores values by `Witness.Key` conformance, which requires Sendable. Unaffected.

**`@Witness` macro** — generates `extension T: Witness_Primitives.__WitnessProtocol {}`. If `Witness.Protocol` loses `Sendable`, `@Witness`-annotated types would need `Sendable` declared on the struct itself. But in practice, all `@Witness` types already declare `: Sendable` on the struct (it's the standard pattern). Unaffected.

**Existing conformances** (13 types across algebra, sample, optic, etc.) — all declare `Sendable` explicitly:
```swift
// Every single one follows this pattern:
public struct Magma<Element: Sendable>: Sendable, Witness.`Protocol` { ... }
```
Removing `Sendable` from `Witness.Protocol` changes nothing for these types.

**Test** — the test `Witness.Protocol is a marker protocol with no requirements beyond Sendable` needs its name updated. The `MinimalWitness` struct in the test is already `Sendable` implicitly (no stored properties that aren't Sendable).

## Outcome

**Status**: DECISION

**Decision**: Remove `Sendable` from `Witness.Protocol` (Option B).

**Rationale**: `Witness.Protocol` is a semantic marker meaning "this type follows the closure-struct witness pattern." Whether the witness can cross isolation boundaries is an orthogonal concern properly handled by `Sendable` on the type itself and by `Witness.Key`'s own Sendable constraint. Requiring Sendable on the marker protocol conflates two independent properties and excludes legitimate witnesses.

This aligns with the principle established in the nonsending adoption audit: Sendable should be required at the points where isolation-domain crossing actually occurs, not as a blanket constraint on semantic categories.

**Changes required**:

1. `swift-witness-primitives`: Remove `: Sendable` from `Witness.Protocol` definition
2. `swift-witness-primitives`: Update test name and assertion
3. No changes needed for any existing conforming types

## References

- `witnesses-ecosystem-adoption-audit.md` — triggered this investigation
- `nonsending-adoption-audit.md` — established principle of Sendable-only-where-needed
- `callback-isolated-nonsending-design.md` — demonstrated orthogonality of Sendable and capability abstraction
