# Revisiting Tagged Production Literal Conformances

<!--
---
version: 2.0.0
last_updated: 2026-03-04
status: DECISION
tier: 2
---
-->

## Context

`tagged-literal-conformances.md` v2.0 (2026-02-11, DECISION) concluded that `ExpressibleByIntegerLiteral` must not be added to `Tagged` in production code, based on a crash in `Bit.Vector.Dynamic Tests.swift`. This research revisits that decision by examining whether the root cause was the literal conformance itself or a separate design flaw that has an independent fix.

**Trigger**: `Time.Offset` design for swift-translating requires `Tagged<Time.Year, Int>`, `Tagged<Time.Month, Int>`, etc. as displacement components. Without production `ExpressibleByIntegerLiteral`, the ergonomic init `Time.Offset(years: 2, months: 3)` requires a convenience init that takes `Int` and wraps internally — workable but worth re-examining the constraint.

## Question

Was the `Bit.Vector.Dynamic` crash caused by `ExpressibleByIntegerLiteral` on `Tagged` being inherently unsafe, or by the unlabeled cross-domain init `Bit.Index.init(_ index: Index<UInt8>)` — a separate design flaw with an independent fix?

## Analysis

### Decomposing the Crash

The crash required **three components** interacting:

| Component | What | Where |
|-----------|------|-------|
| 1. Blanket literal conformance | `Tagged: ExpressibleByIntegerLiteral` | `Tagged Primitives Test Support.swift` |
| 2. Unlabeled cross-domain init | `Bit.Index.init(_ index: Index<UInt8>)` — multiplies by 8 | `Bit.Index+Byte.swift` (still present, unfixed) |
| 3. Swift literal type inference | `.map(Bit.Index.init)` infers `Range<Index<UInt8>>` | Swift compiler |

The resolution chain: `(0..<5).map(Bit.Index.init)` → compiler finds unlabeled `init(_ : Index<UInt8>)` → `Index<UInt8>` accepts literals → `0..<5` inferred as `Range<Index<UInt8>>` → each value passes through ×8 conversion → crash.

### Root Cause Attribution

**Removing any single component prevents the crash:**

| Remove component | Effect |
|-----------------|--------|
| Remove literal conformance (v2.0 decision) | `Index<UInt8>` can't accept literals → `Range<Index<UInt8>>` can't be inferred |
| Add label to cross-domain init (`byte:`) | `.map(Bit.Index.init)` doesn't match labeled init → different overload selected |
| Don't write `.map(Type.init)` | No function-reference context → no ambiguity |

The v2.0 decision removed component 1. But the `cross-domain-init-overload-resolution-footgun.md` research (same date, same author) independently identified component 2 as the root cause and recommended fixing it:

> "Cross-domain conversion inits are legitimate. **The problem is not the existence of the init but its unlabeled form** enabling accidental use."

The recommended fix (Option A: add `byte:` label) was **never applied**. `Bit.Index+Byte.swift` still has the unlabeled `init(_ index: Index<UInt8>)` as of today.

### The Two Fixes Are Independent

| Fix | What it prevents | Scope |
|-----|-----------------|-------|
| Label cross-domain inits | Prevents `.map(Type.init)` from matching cross-domain conversions | Eliminates the class of bug |
| Remove literal conformance | Prevents literal ranges from being inferred as `Range<Tagged<...>>` | Removes one enabler |

Fix 1 (labeling) eliminates the footgun regardless of whether literals exist. Fix 2 (no literals) prevents one specific trigger but leaves the unlabeled init as a latent hazard — it can still fire when non-literal `Index<UInt8>` values are passed through `.map(Bit.Index.init)`.

### Was the v2.0 Decision Correct?

The v2.0 decision was **reactive** — it blamed the literal conformance because that was the component unique to the crash scenario (test code imports test support). But the cross-domain research identified the deeper issue: unlabeled cross-domain inits are the structural anti-pattern.

**Arguments that v2.0 was correct (defense-in-depth):**
- Literal conformance widens the surface area — more types accept literals, more inference chains possible
- Even with labeled inits, novel footguns could emerge from combinations not yet identified
- Conservative approach: don't add conformances that increase type inference complexity

**Arguments that v2.0 over-corrected:**
- The actual root cause (unlabeled init) was identified but not fixed
- The literal conformance serves legitimate purposes (dimensional types, angles, Time.Offset components)
- The convention "cross-domain inits MUST use labels" (Option D) is the principled fix — it prevents the entire class of bug
- Blaming the literal conformance means 83+ Tagged typealiases lose ergonomic construction for a bug caused by one unlabeled init
- The footgun exists even without literals — passing a non-literal `Index<UInt8>` through `.map(Bit.Index.init)` triggers the same ×8 conversion

### Option A: Restore Production Literal Conformance + Enforce Labeled Cross-Domain Inits

**Approach**: Two complementary changes:
1. Move `ExpressibleByIntegerLiteral` (and `ExpressibleByFloatLiteral`) to production code on `Tagged`
2. Apply the `byte:` label fix to `Bit.Index+Byte.swift` (and audit for other unlabeled cross-domain inits)
3. Promote the convention: "Cross-domain conversion inits on Tagged types MUST use argument labels" to a skill rule

**Pros**:
- Fixes the actual root cause (unlabeled init)
- Restores ergonomic construction for all 83+ Tagged typealiases
- `Time.Offset(years: 2, months: 3)` works with `Tagged<Time.Year, Int>` properties directly
- Default parameter values work: `minX: W3C_SVG2.X = 0`
- Consistent with `Scale` and `Interval.Unit` which already have literal conformances in production
- Defense-in-depth: the label convention prevents the class of bug regardless of literal conformance

**Cons**:
- `Kernel.User.ID = 0` becomes possible (identity types accept literals) — but this is ergonomic, not unsafe
- Wider type inference surface area in principle (though the label convention eliminates known footgun vectors)

**Required work**:
1. Add `byte:` label to `Bit.Index+Byte.swift:29` — `init(byte index: Index<UInt8>)`
2. Audit all `init(_ :)` on Tagged types where parameter is a different Tagged specialization
3. Move literal conformances from test support to production in tagged-primitives
4. Update `tagged-literal-conformances.md` to v3.0

### Option B: Keep v2.0 Decision, Fix the Unlabeled Init Separately

**Approach**: Apply the `byte:` label fix (it should be done regardless), but keep literal conformance test-only.

**Pros**:
- Maximum caution — no production literal conformance
- Both fixes applied (belt and suspenders)

**Cons**:
- 83+ Tagged typealiases remain ergonomically impaired in production
- `Time.Offset` requires convenience init wrapping `Int` → `Tagged` internally
- `.init(0)` or `_unchecked:` for default arguments remains awkward
- Diverges from `Scale` and `Interval.Unit` which have production literals

### Option C: Protocol-Gated Production Literal Conformance

**Approach**: Add literal conformance only for specific Underlying types that don't participate in cross-domain init chains.

For example, `Tagged<Tag, Int>` and `Tagged<Tag, Double>` are safe because:
- `Int`-backed Tagged types (Time.Offset components, Kernel IDs) don't have cross-domain init chains
- `Double`-backed Tagged types (coordinates, displacements, angles) have `Spatial`-gated inits, not cross-domain ordinal inits
- The footgun only fires with `Ordinal`-backed types that have cross-domain inits

However, `Ordinal: ExpressibleByIntegerLiteral` already exists in production (ordinal-primitives), so `Tagged<Tag, Ordinal>` would still gain the conformance through the blanket `Underlying: ExpressibleByIntegerLiteral` constraint.

**Variant C2**: Gate on `Underlying` NOT being `Ordinal`:
```swift
// Not expressible in Swift's type system — can't do negative constraints
```

This is not viable. Swift doesn't support `where Underlying != Ordinal` constraints.

**Variant C3**: Gate on a marker protocol:
```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, Underlying: ExpressibleByIntegerLiteral & Tagged.LiteralSafe { ... }
```

Then `Int`, `Double`, etc. conform to `LiteralSafe` but `Ordinal` does not. However, this introduces a marker protocol — conflicting with ecosystem conventions.

**Assessment**: Not viable without language features for negative constraints or acceptable marker protocols.

### Comparison

| Criterion | A: Restore + Label | B: Keep v2.0 + Label | C: Protocol-gated |
|-----------|-------------------|---------------------|-------------------|
| Fixes root cause | Yes | Yes | Partially |
| Ergonomic construction | Excellent | Poor | Partial |
| Time.Offset design | Clean (Tagged with literals) | Workaround (Int init) | Depends |
| Identity type safety | Good (literals only) | Excellent | Excellent |
| Ordinal footgun risk | Eliminated by label convention | Eliminated by both | Eliminated by both |
| Implementation complexity | Low | Low | High |
| Consistency with Scale/Unit | Yes | No | Partial |

## Constraints

1. The `byte:` label fix should be applied **regardless** of the literal conformance decision — the unlabeled cross-domain init is a latent bug even without literals
2. `Ordinal: ExpressibleByIntegerLiteral` exists in production and cannot be removed (it's used across the ecosystem for ordinal construction)
3. Swift does not support negative type constraints (`where Underlying != Ordinal`)
4. The single conditional conformance slot concern (from v2.0 Option B) applies — Swift doesn't allow multiple conditional conformances to the same protocol with different constraints

### Critical Finding: Unlabeled Inits Are the Canonical Convention

Per [PATTERN-012], cross-domain conversions canonically live in unlabeled `init(_ : SourceType)` on the target type. This is not one init to fix — it is a foundational ecosystem convention. Examples across the ecosystem:

```swift
// Bit.Index from byte index (×8)
Bit.Index.init(_ index: Index<UInt8>)

// Index from Count (ordinal from cardinal)
Index<T>.init(_ count: Index<T>.Count)

// Ordinal from Cardinal
Ordinal.init(_ cardinal: Cardinal)

// And many more cross-domain Tagged→Tagged conversions...
```

These are all unlabeled, all canonical, and all would become footgun vectors if `ExpressibleByIntegerLiteral` were added to Tagged in production.

**This changes the analysis fundamentally.** Option A (Restore + Label) is not "label one init" — it is "change a foundational convention and label every cross-domain init across 61+ packages." This is infeasible.

### Revised Assessment: Identity-Numeric Safety

The v2.0 decision was based on the premise that blanket `ExpressibleByIntegerLiteral` on `Tagged` + unlabeled cross-domain inits = silent wrong results. This is correct for **non-identity** transformations (e.g., Bit.Index ×8 scaling). But it was overly broad — the vast majority of cross-domain inits (6 of 9) are **identity-numeric**, preserving the underlying value while changing the semantic domain.

**Key insight**: Identity-numeric cross-domain inits are VALUE-SAFE even under wrong type inference paths.

```swift
// With Tagged literal conformance, Swift could infer 0..<5 as Range<Index<Element>>
let counts = (0..<5).map(Index<Element>.Count.init)
// Each Index<Element> passes through Tagged<Tag,Cardinal>.init(_: Tagged<Tag,Ordinal>)
// Identity numeric → [0, 1, 2, 3, 4] — CORRECT values
```

The type inference path is unexpected (went through ordinal instead of directly), but the numeric output is identical. This holds for ALL identity-numeric inits by mathematical definition.

**The 3 non-identity inits** — `Bit.Index` (×8 scaling), `Memory.Shift` (narrowing), `Affine.Discrete.Ratio` (reinterpretation) — are the ONLY ones that produce wrong values under unexpected type inference. These were exhaustively verified across all 61+ packages. Labeling them eliminates the entire footgun class.

**Safety verification**:

| Risk | Assessment |
|------|-----------|
| Wrong values from identity-numeric inference | **Impossible** — identity preserves underlying value by definition |
| Wrong values from non-identity inference | **Eliminated** — all 3 non-identity inits labeled |
| Throwing inits as footgun vectors | **Safe** — throwing inits can't be matched by non-throwing `.map(Type.init)` |
| Future unlabeled non-identity inits | **Convention-enforced** — "unlabeled init MUST preserve numeric identity" |
| Overload resolution surprises | **None identified** — default params, switch/case, generic contexts all benefit |
| Identity type literal acceptance | **Ergonomic benefit** — `Kernel.User.ID = 0` is convenient, not unsafe |

This changes the structural incompatibility finding. The ecosystem convention of unlabeled `init(_ :)` as canonical cross-domain conversion is compatible with blanket `ExpressibleByIntegerLiteral` on `Tagged` — **as long as all unlabeled inits are identity-numeric**. The convention rule "unlabeled init MUST preserve numeric identity" enforces this going forward.

## Outcome

**Status**: DECISION

**Decision**: v2.0 superseded — production `ExpressibleByIntegerLiteral` on `Tagged` is safe, contingent on labeling the 3 non-identity cross-domain inits.

**Rationale** (v2.0 of this document, supersedes v1.0):
1. The confirmed crash (Bit.Index ×8) was caused by a non-identity transformation, not by literal conformance per se
2. All remaining unlabeled cross-domain inits are identity-numeric — they preserve underlying values and cannot produce wrong results even under unexpected type inference
3. Labeling the 3 non-identity inits eliminates the entire footgun class with near-zero migration cost (~10 call sites)
4. Production literal conformance restores ergonomic construction for 83+ Tagged typealiases
5. The convention "unlabeled init MUST preserve numeric identity" is enforceable and prevents future regressions
6. Consistent with `Scale` and `Interval.Unit` which already have production literal conformances

**Required implementation**:
1. Label `Bit.Index.init(_ index: Index<UInt8>)` → `Bit.Index.init(byte index: Index<UInt8>)` — 0 `.map` call sites
2. Label `Memory.Shift.init(_ cardinal: Cardinal)` → `Memory.Shift.init(count cardinal: Cardinal)` — 0 `.map` call sites
3. Label `Affine.Discrete.Ratio.init(_ count: Tagged<To, Cardinal>)` → `Affine.Discrete.Ratio.init(stride count: Tagged<To, Cardinal>)` — 0 `.map` call sites
4. Move `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` from test support to production in tagged-primitives
5. Update `tagged-literal-conformances.md` to v3.0

**Convention rule** (to be codified in implementation skill): "Unlabeled `init(_ :)` on Tagged types MUST preserve numeric identity. Non-identity transformations (scaling, narrowing, reinterpretation) MUST use argument labels."

**Implication for Time.Offset**: With production literal conformance, `Tagged<Time.Year, Int>` accepts literals directly. `Time.Offset(years: 2, months: 3)` works cleanly whether the stored properties are `Tagged<Time.Year, Int>` or plain `Int`. A convenience init accepting `Int` parameters is still good API design per [IMPL-010].

## References

- `tagged-literal-conformances.md` v3.0 — updated DECISION (production literal conformance approved)
- `swift-primitives/Research/labeled-cross-domain-init-convention.md` — cross-domain init inventory and safety analysis
- `cross-domain-init-overload-resolution-footgun.md` — original root cause analysis (2026-02-11)
- `Bit.Index+Byte.swift` — non-identity unlabeled init (to be labeled `byte:`)
- `Memory.Shift+Cardinal.Protocol.swift` — non-identity unlabeled init (to be labeled `count:`)
- `Affine.Discrete.Ratio+Tagged.swift` — non-identity unlabeled init (to be labeled `stride:`)
- `Ordinal+ExpressibleByIntegerLiteral.swift` — Ordinal production literal conformance
- `Tagged Primitives Test Support.swift` — literal conformances to be moved to production
- `foundation-free-time-and-locale-in-swift-translating.md` — Time.Offset trigger
