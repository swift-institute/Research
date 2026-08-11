# Zero and One Static Declarations for Algebra.Z

<!--
---
version: 1.0.0
last_updated: 2026-02-06
status: DECISION
---
-->

## Context

`Algebra.Z<n>` is `Tagged<Residue<n>, Ordinal>`. It needs public `.zero` and `.one` static properties for modular arithmetic. Currently both are declared `internal` in `Algebra.Z+Arithmetic.swift` because making them `public` caused ambiguity.

**Trigger**: Preparing `Algebra.Z<n>` for public use as cyclic-primitives replacement requires these to be publicly accessible.

## Question

Where should `.zero` and `.one` be declared so they are publicly available on `Algebra.Z<n>` without ambiguity?

## Analysis

### The Conflict

Two extensions match `Algebra.Z<n>` = `Tagged<Residue<n>, Ordinal>`:

| Source | Extension constraint | Visibility |
|--------|---------------------|------------|
| `ordinal-primitives` `Tagged+Ordinal.swift:23` | `Tagged where RawValue == Ordinal, Tag: ~Copyable` | `public` |
| `algebra-modular-primitives` `Algebra.Z+Arithmetic.swift:6` | `Tagged where Tag: Algebra.Residual, RawValue == Ordinal` | `internal` |

Both produce identical values for `.zero` — `Ordinal(0)`. The ordinal-primitives declaration is broad (all `Tagged<_, Ordinal>`), the algebra one is narrow (only residue-tagged types). If both were `public`, Swift sees two candidate `.zero` on `Algebra.Z<n>` from two different modules — ambiguity.

For `.one`, only the algebra extension declares it. No conflict exists.

### Dependency Chain

```
Algebra_Modular_Primitives
  → Finite_Primitives
    → Ordinal_Primitives  (includes Tagged+Ordinal.swift)
```

The ordinal-primitives `.zero` is already transitively visible to all consumers of algebra-modular-primitives.

### Option A: Delete Algebra `.zero`, Make `.one` Public

Remove the algebra-specific `.zero` entirely. Rely on ordinal-primitives for `.zero`. Make `.one` public.

```swift
// Algebra.Z+Arithmetic.swift — AFTER
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    /// Multiplicative identity / generator of Z/nZ.
    @inlinable
    public static var one: Self {
        Self(__unchecked: (), Ordinal(UInt(Tag.capacity > 1 ? 1 : 0)))
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| `.zero` available? | Yes — from ordinal-primitives, public, already works |
| `.one` available? | Yes — from algebra-modular, public, no conflict |
| Ambiguity? | None — single declaration per property |
| Semantic correctness | `.zero` = additive identity of Z/nZ = `Ordinal(0)` — identical |
| Dependency coupling | `.zero` semantics owned by ordinal layer — correct layering |

### Option B: Keep Both, Use `@_disfavoredOverload`

Mark the algebra `.zero` as `@_disfavoredOverload` so ordinal-primitives wins in ambiguous contexts.

```swift
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    @_disfavoredOverload
    @inlinable
    public static var zero: Self { Self(__unchecked: (), Ordinal(0)) }

    @inlinable
    public static var one: Self { ... }
}
```

| Criterion | Assessment |
|-----------|------------|
| Ambiguity? | Suppressed via annotation, not eliminated |
| Maintenance | Fragile — depends on underscored attribute |
| Semantic correctness | Redundant — both produce `Ordinal(0)` |

### Option C: Move Both into Ordinal Primitives

Add `.one` to ordinal-primitives alongside `.zero`, gated by a protocol.

Rejected immediately: `.one` does not have universal meaning for all `Tagged<_, Ordinal>`. An `Index<Element>` has `.zero` (the first position) but `.one` is meaningless without a group structure. This would leak algebraic semantics into a positional layer.

## Evaluation

| Criterion | Weight | Option A | Option B |
|-----------|--------|----------|----------|
| No ambiguity | Critical | Eliminated | Suppressed |
| No underscored attributes | High | Clean | `@_disfavoredOverload` |
| Single source of truth | High | Yes | No — duplicated |
| Correct layering | High | Yes | Yes |
| Simplicity | Medium | Minimal | More code |

## Decision

**Option A: Delete the algebra-specific `.zero`, make `.one` public.**

### Rationale

1. **`.zero` on `Tagged<_, Ordinal>` is universally correct.** The zero ordinal is always `Ordinal(0)`. There is no residue-class-specific semantics — the additive identity of Z/nZ IS ordinal zero. Ordinal-primitives already declares this correctly and publicly.

2. **`.one` IS algebra-specific.** The generator/multiplicative identity of Z/nZ only makes sense in a group/ring context. The `Tag: Algebra.Residual` constraint correctly scopes it to residue types. The `capacity > 1 ? 1 : 0` logic handles the Z/1Z degenerate case — this IS algebraic knowledge that doesn't belong in ordinal-primitives.

3. **No redundancy, no ambiguity, no workarounds.** A single public declaration per property. Clean resolution.

### Implementation

In `Algebra.Z+Arithmetic.swift`:
- Delete `internal static var zero`
- Change `internal static var one` to `public static var one`

No other files change.

## References

- `swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift:23` — existing public `.zero`
- `swift-algebra-modular-primitives/Sources/Algebra Modular Primitives/Algebra.Z+Arithmetic.swift:6,10` — current internal declarations
- `swift-algebra-modular-primitives/Sources/Algebra Modular Primitives/Algebra.Residual.swift` — `Residual` protocol
