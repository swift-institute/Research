# Arithmetic Delegation Pattern for Cyclic Index

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
---
-->

## Context

During the extraction of `swift-cyclic-index-primitives` from `swift-cyclic-primitives`, a question arose about the placement of arithmetic operators. The user observed that `swift-index-primitives` removed its arithmetic because it now comes from `ordinal/cardinal/affine-primitives`. Should the same pattern apply to `swift-cyclic-index-primitives` and `swift-cyclic-primitives`?

## Question

Should the Tagged arithmetic operators currently in `swift-cyclic-index-primitives` be moved to `swift-cyclic-primitives`, following the pattern where primitive packages provide Tagged extensions for their types?

## Analysis

### Current State

**swift-cyclic-primitives (Tier 8)** provides:
- `Cyclic.Group<N>.Element` with arithmetic (`+`, `-`, `+=`, `-=`)
- Identity elements (`.zero`, `.one`)
- Additive inverse (`.inverse`)
- NO Tagged extensions

**swift-cyclic-index-primitives (Tier 9)** provides:
- `Index<Tag>.Cyclic<N>` typealias
- Tagged+Tagged operators (`+`, `-`, `+=`, `-=`)
- Tagged+Element operators (enables `.zero`/`.one` syntax)
- Construction helpers

### The Index-Primitives Pattern

`swift-index-primitives` delegates arithmetic through a layered approach:

| Operation | Defined In | Delegates To |
|-----------|------------|--------------|
| `Index + Count` | `swift-ordinal-primitives` | `Ordinal + Cardinal` |
| `Index + Offset` | `swift-affine-primitives` | `Ordinal + Affine.Discrete.Vector` |
| `Index - Index` | `swift-affine-primitives` | `Ordinal - Ordinal` → `Vector` |

Key insight: The arithmetic lives in the **primitive package that defines the raw type**, not in the index package.

### Option A: Move Tagged Arithmetic to cyclic-primitives

Move the 8 operator definitions from `Index.Cyclic.swift` to a new file `Tagged+Cyclic.Group.Element.swift` in `swift-cyclic-primitives`.

**Advantages:**
- Follows the ordinal/affine pattern exactly
- Cyclic-primitives becomes self-contained for all cyclic arithmetic
- Any package using `Tagged<T, Cyclic.Group<N>.Element>` gets arithmetic automatically
- Reduces cyclic-index-primitives to pure typealias + construction

**Disadvantages:**
- Requires cyclic-primitives to depend on identity-primitives (for `Tagged`)
- Adds a Tier 0 dependency to a Tier 8 package (architectural concern)
- Cyclic-primitives currently has no identity-primitives dependency

**Tier Impact:**
```
Current cyclic-primitives dependencies:
- comparison-primitives (Tier 2)
- hash-primitives (Tier 3)
- sequence-primitives (Tier 7)

Adding identity-primitives (Tier 0) would not change the tier.
```

### Option B: Keep Tagged Arithmetic in cyclic-index-primitives

Leave the current structure unchanged.

**Advantages:**
- No changes needed to cyclic-primitives
- Cyclic-primitives remains focused on pure cyclic algebra
- Tagged arithmetic is specialized for the index use case
- Follows the join-point pattern (integration in higher-tier package)

**Disadvantages:**
- Inconsistent with ordinal/affine pattern
- If another package wants `Tagged<T, Cyclic.Group<N>.Element>` arithmetic, must depend on cyclic-index-primitives
- The `Tagged + Element` operators (for `.zero`/`.one` syntax) might be wanted elsewhere

### Option C: Split - Base Operators in cyclic-primitives, Convenience in cyclic-index

Move `Tagged + Tagged` operators to cyclic-primitives; keep `Tagged + Element` operators in cyclic-index-primitives.

**Advantages:**
- Core arithmetic available at the primitive layer
- Convenience syntax stays in the specialized package
- Partial consistency with the pattern

**Disadvantages:**
- Splits related functionality across packages
- More complex mental model
- Still requires identity-primitives dependency in cyclic-primitives

### Comparison

| Criterion | Option A (Move All) | Option B (Keep) | Option C (Split) |
|-----------|---------------------|-----------------|------------------|
| Pattern consistency | ✓ Best | ✗ Inconsistent | ~ Partial |
| Dependency simplicity | ~ Adds Tier 0 dep | ✓ No change | ~ Adds Tier 0 dep |
| Reusability | ✓ Any Tagged user | ✗ Must use index pkg | ~ Partial |
| Complexity | ✓ Simple | ✓ Simple | ✗ Split logic |
| Cyclic-primitives focus | ~ Broader scope | ✓ Pure algebra | ~ Broader scope |

### Architectural Consideration

The ordinal/affine packages provide Tagged extensions because `Tagged<T, Ordinal>` IS the fundamental abstraction—`Index<T>` is just a typealias for it. The arithmetic semantics are intrinsic to the wrapped type.

Similarly, `Tagged<T, Cyclic.Group<N>.Element>` has intrinsic cyclic arithmetic semantics. The wrapping/modular behavior is defined by the element type, not by the "index" interpretation.

However, there's a key difference:
- `Ordinal` is designed to be wrapped in `Tagged` (it's an opaque position)
- `Cyclic.Group<N>.Element` is a self-contained algebraic type that can be used directly

This suggests cyclic-primitives is more "complete" on its own, and Tagged support is optional enhancement.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A — Move Tagged arithmetic to `swift-cyclic-primitives`

**Rationale:**

1. **Pattern consistency**: Following the established ordinal/affine pattern reduces cognitive load and makes the architecture predictable.

2. **Reusability**: Any package that creates `Tagged<T, Cyclic.Group<N>.Element>` should get arithmetic for free, without needing to depend on the index package.

3. **Semantic correctness**: The wrapping arithmetic is intrinsic to `Cyclic.Group<N>.Element`, not to its interpretation as an "index". The Tagged operators merely forward to the underlying type.

4. **Minimal dependency impact**: Adding `identity-primitives` (Tier 0) to cyclic-primitives (Tier 8) does not change its tier placement.

**Implementation:**

1. Add `identity-primitives` dependency to `swift-cyclic-primitives`
2. Create `Tagged+Cyclic.Group.Element.swift` in cyclic-primitives with:
   - Tagged + Tagged operators
   - Tagged + Element operators (for `.zero`/`.one`)
   - Compound assignment operators
3. Remove the 8 operator definitions from `Index.Cyclic.swift` in cyclic-index-primitives
4. Keep only the typealias and construction helpers in cyclic-index-primitives
5. Update exports in both packages

**cyclic-index-primitives after refactor:**
```swift
// Index.Cyclic.swift - reduced to ~30 lines
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public typealias Cyclic<let N: Int> = Tagged<Tag, Cyclic_Primitives.Cyclic.Group<N>.Element>
}

extension Tagged where Tag: ~Copyable {
    public init<let N: Int>(_ position: Int) throws(...)
    where RawValue == Cyclic_Primitives.Cyclic.Group<N>.Element { ... }

    public init<let N: Int>(__unchecked position: Int)
    where RawValue == Cyclic_Primitives.Cyclic.Group<N>.Element { ... }
}
```

## References

- `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift`
- `/Users/coen/Developer/swift-primitives/swift-affine-primitives/Sources/Affine Primitives/Tagged+Affine.swift`
- `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group+Arithmetic.swift`
- `/Users/coen/Developer/swift-primitives/swift-cyclic-index-primitives/Sources/Cyclic Index Primitives/Index.Cyclic.swift`
