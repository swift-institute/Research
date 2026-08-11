# Vector Unit Displacement Layering

<!--
---
version: 1.1.0
last_updated: 2026-05-09
status: SUPERSEDED
status_note: |
  Superseded 2026-05-09 by the Carrier migration (carrier-primitives 2b57aac
  landed 2026-04-29; cohort-wide migration to `Carrier.Protocol where
  Underlying == Affine.Discrete.Vector` substrate). The recommendation's
  premise — that `.one` lived in `swift-algebra-affine-primitives` and was
  invisible at the collection-primitives layer — no longer applies. The
  vector `.one` is now provided by the `Carrier.Protocol where Underlying ==
  Affine.Discrete.Vector` extension in this package
  (`Affine.Discrete.Vector+Carrier.swift`), inherited by every
  `Tagged<Tag, Affine.Discrete.Vector>` consumer including the typed-offset
  surface used at the collection layer. Original analysis preserved below
  for historical context.
---
-->

## Context

`Index<T>.Offset` is `Tagged<T, Affine.Discrete.Vector>`. Writing `.one` on this type fails at the collection-primitives layer because the only visible `.one` is `Cardinal.Protocol.one` (requires `RawValue == Cardinal`), while the vector-specific `.one` lives in `Algebra_Affine_Primitives` — a module not available at the primitives layer.

**Trigger**: `Collection.Rotated` tests use `startOffset: .one` which fails:
```
error: referencing static property 'one' on 'Tagged' requires the types
'Affine.Discrete.Vector' and 'Cardinal' be equivalent
```

This is NOT an ambiguity problem. It is a **missing import** — the vector `.one` is at the wrong layer.

### Related Research

- `swift-algebra-modular-primitives/Research/zero-one-static-declarations.md` — established the principle: `.zero` is universal (lives at lowest layer), `.one` is algebraic (lives at algebra layer)
- `swift-algebra-affine-primitives/Experiments/protocol-extension-layer-visibility/` — validated that protocol-extension `.one` on vectors does NOT cause ambiguity with Cardinal's `.one`

## Question

Should `.one` for `Affine.Discrete.Vector.Protocol` move from the algebra layer to the affine-primitives layer, eliminating the missing-import problem permanently?

## Analysis

### Current Layering

```
swift-affine-primitives          → .zero on Affine.Discrete.Vector.Protocol
swift-algebra-affine-primitives  → .one  on Affine.Discrete.Vector.Protocol
```

`.zero` is available everywhere. `.one` requires an algebra-layer import.

### Why `.one` Was Placed at the Algebra Layer

The comment in `Affine.Discrete.Vector.Protocol+One.swift` states:

> "Provided at the algebra layer because `.one` is a ring/module concept
> (unit element for scalar action), not a fundamental affine concept."

### Why This Reasoning Is Flawed

1. **`.zero` is equally algebraic.** The additive identity is a group/ring concept. If `.zero` belongs at the affine layer, the same argument applies to `.one`. The current split is inconsistent.

2. **Unit displacement is fundamental to discrete spaces.** Every discrete affine space has a canonical unit step. You need it for:
   - `index(after:)` — advance by one position
   - Iterator stepping
   - The concept of "next" / "previous"
   - Basic offset arithmetic (`offset + .one`)

   This is geometric, not algebraic. You don't need multiplication to define "move one step."

3. **Every downstream consumer needs it.** Any package that works with `Index.Offset` needs unit displacement — collection-primitives, buffer-primitives, sequence-primitives, etc. Forcing them to depend on `Algebra_Affine_Primitives` to write `.one` on an offset is a layering inversion.

### Ambiguity Analysis

If `.one` moves to affine-primitives, it becomes visible alongside `Cardinal.Protocol.one` at every layer. Is this safe?

**Yes — the constraints are mutually exclusive:**

| Protocol | Conformance constraint on `Tagged` | `.one` type |
|----------|-----------------------------------|-------------|
| `Cardinal.Protocol` | `RawValue == Cardinal` | count semantics |
| `Affine.Discrete.Vector.Protocol` | `RawValue == Affine.Discrete.Vector` | displacement semantics |

No `Tagged` specialization satisfies both constraints. The compiler selects the unique matching candidate:

| Expression | Expected type | Resolved `.one` |
|-----------|--------------|----------------|
| `Index<T>.Count.one` | `Tagged<T, Cardinal>` | `Cardinal.Protocol.one` |
| `Index<T>.Offset.one` | `Tagged<T, Affine.Discrete.Vector>` | `Vector.Protocol.one` |
| `Ordinal(.one)` | `Cardinal` (init parameter) | `Cardinal.Protocol.one` |

**Validated empirically** in `swift-algebra-affine-primitives/Experiments/protocol-extension-layer-visibility/variant-algebra/`:
> "Vector.one works via protocol extension, AND Ordinal(.one) resolves to Cardinal.one (non-throwing) even with AlgebraExtension imported."

**Caveat**: The experiment's `Cardinal.one` was a direct member, while the real codebase uses protocol extension. However, the disambiguation mechanism here is different — it's not priority-based but **constraint-based**. Only one conformance matches per concrete `Tagged` specialization, so there is exactly one candidate regardless of how it's defined.

### Option A: Move `.one` to Affine-Primitives

Move `Affine.Discrete.Vector.Protocol+One.swift` from `swift-algebra-affine-primitives` to `swift-affine-primitives`.

| Criterion | Assessment |
|-----------|------------|
| Ambiguity | None — mutually exclusive constraints, empirically validated |
| Consistency | `.zero` and `.one` both at affine layer |
| Downstream availability | All packages that use `Offset` get `.one` for free |
| Layering | Correct — unit displacement is fundamental to discrete affine spaces |
| Change scope | One file move, zero API changes |

### Option B: Rename to `.unit` for Vectors

Rename `.one` to `.unit` on `Affine.Discrete.Vector.Protocol`. Move to affine-primitives.

| Criterion | Assessment |
|-----------|------------|
| Ambiguity | Eliminated permanently — different name |
| Consistency | Breaks `.zero`/`.one` mathematical pair |
| Semantics | "unit displacement" is precise but unconventional |
| Ergonomics | `startOffset: .unit` vs `startOffset: .one` — `.one` reads better |
| Discoverability | `.unit` is non-standard, harder to guess |

### Option C: Keep at Algebra Layer, Use Integer Literals

No changes. Write `1` or `Index.Offset(1)` instead of `.one`.

| Criterion | Assessment |
|-----------|------------|
| Ambiguity | N/A — avoids the property entirely |
| Consistency | Inconsistent — `.zero` works but `.one` doesn't |
| Ergonomics | Less discoverable, requires knowing raw construction |
| Layering | Leaves the inconsistency in place permanently |

## Evaluation

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| No ambiguity | Critical | Validated | Guaranteed | N/A |
| Consistency with `.zero` | High | Both at same layer | Different name | Asymmetric |
| Ergonomics | High | `.one` reads naturally | `.unit` uncommon | Manual construction |
| Correct layering | High | Unit step is fundamental | Same | Wrong layer |
| Change scope | Medium | One file move | One file move + rename | None |

## Recommendation

**Option A: Move `.one` to affine-primitives.**

### Rationale

1. **Unit displacement is fundamental.** `index(after:)`, stepping, iteration — all need "plus one." This is a discrete affine space concept, not an algebraic one.

2. **`.zero` sets the precedent.** The additive identity already lives at affine-primitives. The unit displacement belongs beside it.

3. **No ambiguity risk.** Mutually exclusive conformance constraints (`RawValue == Cardinal` vs `RawValue == Affine.Discrete.Vector`) guarantee the compiler always selects the correct `.one`. Empirically validated.

4. **Eliminates a class of errors.** Every package that uses `Offset` types can write `.one` without depending on the algebra layer. The "missing import" problem disappears permanently.

### Implementation

1. Move `swift-algebra-affine-primitives/Sources/Algebra Affine Primitives/Affine.Discrete.Vector.Protocol+One.swift` to `swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Vector.Protocol+One.swift`
2. Update the file comment to reflect the new rationale
3. Verify `swift-algebra-affine-primitives` still builds (it re-exports affine-primitives, so consumers see no change)
4. Verify `swift-collection-primitives` tests can use `.one` on offsets

## References

- `swift-algebra-modular-primitives/Research/zero-one-static-declarations.md` — prior art on `.zero`/`.one` layering
- `swift-algebra-affine-primitives/Experiments/protocol-extension-layer-visibility/` — ambiguity validation
- `swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete.Vector.Protocol.swift:57-64` — `.zero` at affine layer
- `swift-algebra-affine-primitives/Sources/Algebra Affine Primitives/Affine.Discrete.Vector.Protocol+One.swift` — current `.one` location
- `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift:59-68` — `Cardinal.Protocol` `.zero`/`.one`
