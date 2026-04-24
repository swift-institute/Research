# Deferred Infrastructure Gap Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
---
-->

## Context

The typed call-site refactoring (Phase 9) eliminated ~74 raw `Int(bitPattern:)`, `.rawValue.rawValue`, `Ordinal(UInt(...))`, and `Cardinal(UInt(...))` patterns across 4 packages using existing infrastructure. Six items were deferred because they require **new** infrastructure. This document analyzes whether each proposed addition is principally correct within the affine geometry type model.

**Trigger**: [RES-001] — design question cannot be answered without systematic analysis.

**Scope**: Primitives-wide — affects cardinal-primitives, ordinal-primitives, affine-primitives, memory-primitives, bit-vector-primitives, bit-pack-primitives. [RES-002a]

**Prior art**: `int-bitpattern-conversion-audit.md` (2026-02-06) identified ~225 production `Int(bitPattern:)` sites and classified them by eliminability. Category H ("Bit shift amount", ~10 sites) is directly relevant.

**Type model reference**:

| Type | Raw | Answers | Space |
|------|-----|---------|-------|
| `Ordinal` | `UInt` | "which one?" | Position in discrete affine space |
| `Cardinal` | `UInt` | "how many?" | Quantity / magnitude / count |
| `Affine.Discrete.Vector` | `Int` | "how far?" | Signed displacement |
| `Tagged<T, Ordinal>` | — | Phantom-typed position | `Index<T>` |
| `Tagged<T, Cardinal>` | — | Phantom-typed count | `Index<T>.Count` |
| `Tagged<T, Vector>` | — | Phantom-typed displacement | `Index<T>.Offset` |
| `Affine.Discrete.Ratio<From, To>` | `Int` | "how many To per From?" | Cross-domain morphism |

**Core affine axioms**:
- `Position + Vector → Position` (translation)
- `Position - Position → Vector` (displacement)
- `Vector + Vector → Vector` (composition)
- `Cardinal * Ratio<A, B> → Cardinal` (scaling)
- `Count.map(Ordinal.init) → Index` (cardinal-to-ordinal, total when value ≥ 0)

---

## Gap 1: `FixedWidthInteger << / >> Cardinal.Protocol`

### Question

Should bit shift amounts accept `Cardinal.Protocol` (a count/quantity type)? What is the mathematical nature of a shift amount?

### Analysis

#### What is a shift amount?

A bit shift `value << n` means "shift the bit pattern of `value` left by `n` positions." The operand `n` answers "how many positions?" — this is a quantity. It is:

- Non-negative (negative shifts are expressed as the opposite direction: `>> n` instead of `<< -n`)
- Dimensionless with respect to the shifted value (you shift a `UInt` by a count, not by another `UInt`)
- Bounded: `0 ≤ n < bitWidth` for well-defined behavior

Cardinal answers "how many?" and is UInt-backed (non-negative by representation). This is a natural fit.

#### What the call sites actually have

The deferred shift sites use `Index<Bit>.Offset` (= `Tagged<Bit, Vector>`) as the shift amount:

```swift
// Bit.Pack.Location.swift:63
self.mask = Word(1) << Int(bitPattern: bit)     // bit: Index<Bit>.Offset

// Bit.Vector.Static+clear.range.swift:33
let lowMask: UInt = ~0 << startBit              // startBit: Int(bitPattern: startLoc.bit)
```

`Index<Bit>.Offset` is a **signed displacement** (`Vector`), but these values are always non-negative at the point of use (they represent bit positions within a word, range `0..<bitWidth`). The signed type comes from the general affine framework, not from the domain semantics.

#### Option A: `FixedWidthInteger << Cardinal.Protocol`

```swift
@inlinable
public func << <Tag, RawValue: FixedWidthInteger>(
    lhs: RawValue,
    rhs: Tagged<Tag, Cardinal>
) -> RawValue {
    lhs << Int(bitPattern: rhs)
}
```

**Pros**: Cardinal is the principally correct type for "how many positions to shift." Absorbs the `Int(bitPattern:)` boundary.

**Cons**: The actual values at call sites are `Index<Bit>.Offset` (Vector), not Cardinal. Would require an intermediate conversion: `Offset → Cardinal` (which is `Vector.magnitude` when non-negative, but that's Gap 3). This trades one boundary conversion for another.

#### Option B: `FixedWidthInteger << Ordinal.Protocol`

Shift amounts could be ordinal positions ("shift to position n"). But this is semantically wrong — a shift amount is a count of positions to move, not a position identifier.

**Verdict**: Reject.

#### Option C: `FixedWidthInteger << Vector.Protocol`

Accept Vector directly as shift amount. The Swift stdlib already defines `<<` with `Int` (signed), so this aligns with stdlib convention.

```swift
@inlinable
public func << <Tag, RawValue: FixedWidthInteger>(
    lhs: RawValue,
    rhs: Tagged<Tag, Affine.Discrete.Vector>
) -> RawValue {
    lhs << rhs.vector.rawValue
}
```

**Pros**: Zero friction — call sites write `Word(1) << bit` directly with their existing `Index<Bit>.Offset` values. Aligns with Swift stdlib's `Int` shift convention (signed). No intermediate conversion needed.

**Cons**: Semantically imprecise — a shift amount is a quantity, not a displacement. Negative vectors would silently produce undefined shift behavior.

#### Option D: `FixedWidthInteger << Int(bitPattern:)` boundary overloads only

Keep the existing `<< Int` operators, add `Int(bitPattern:)` overloads on `Ordinal.Protocol` (already exists) and `Vector.Protocol` (via `.rawValue`). The call sites become slightly cleaner but still expose the boundary.

#### Comparison

| Criterion | A: Cardinal | B: Ordinal | C: Vector | D: Boundary |
|-----------|-------------|------------|-----------|-------------|
| Mathematical correctness | Best — shift = count | Wrong | Acceptable — matches stdlib Int | N/A |
| Call site friction | Medium — needs Offset→Cardinal | — | Zero — direct use | Low |
| Safety (rejects negatives) | Yes | — | No | No |
| Matches stdlib convention | No (stdlib uses Int) | No | Yes (Int is signed) | Yes |
| Matches actual types at call sites | No (sites have Offset) | No | Yes | Yes |

### Recommendation

**Option C (Vector.Protocol)** for practical reasons, with a caveat:

1. The call sites uniformly hold `Index<Bit>.Offset` (Vector). Requiring conversion to Cardinal creates friction without safety benefit — the values are already known non-negative by construction (they come from `quotientAndRemainder` which produces `0..<bitWidth`).
2. Swift's own `<<` takes `Int` (signed). Following the same convention with `Vector` (also `Int`-backed and signed) is consistent.
3. The `unsafe` marker at the call site already communicates that the programmer has verified the invariant.

If stronger type safety is desired, Option A (Cardinal) is the principally correct choice, but it requires Gap 3 (Vector.magnitude → Cardinal) to be resolved first, creating a dependency chain.

**Principled correctness**: Shift amounts are quantities (Cardinal), but the stdlib chose signed shift amounts, and our call sites hold Vector values. Option C is pragmatically correct; Option A is mathematically correct. Either is defensible.

---

## Gap 2: `Ordinal(_ vector: Vector) throws`

### Question

Is converting a displacement (Vector) to a position (Ordinal) principally sound?

### Analysis

#### Mathematical model

In the affine space model:
- **Ordinal** is a position: a point in a discrete ordered space, backed by `UInt` (non-negative).
- **Vector** is a displacement: a signed distance between two positions, backed by `Int`.

The relationship between them is defined by the affine axiom: `Position = Origin + Vector`. If we fix the origin at zero, then every non-negative vector corresponds to a unique ordinal:

```
Ordinal(v) = Origin + v = 0 + v = v    (when v ≥ 0)
```

This is partial: negative vectors have no corresponding ordinal (there is no position at offset -3 from zero in a UInt-backed space).

#### Existing infrastructure

The conversion already exists as `Tagged<Tag, Vector>.init(_ ordinal: some Ordinal.Protocol)` — going **from** ordinal **to** vector. The inverse (vector → ordinal) exists only as `__unchecked`:

```swift
// Tagged+Affine.swift — Vector FROM Ordinal (exists)
public init(_ index: some Ordinal.Protocol) throws(Affine.Discrete.Vector.Error) {
    self.init(__unchecked: (), try index.ordinal - Ordinal.zero)
}

// The INVERSE does not exist as a public API
```

#### Where it's needed

```swift
// Cyclic.Group+Arithmetic.swift:121
let forward = Ordinal(UInt(offset.vector.rawValue)) % modulus.value
```

This extracts the Vector's raw `Int`, converts to `UInt`, then wraps in `Ordinal`. The `UInt(...)` init traps on negative values, providing the partiality check at the wrong layer.

#### Proposed API

```swift
extension Ordinal {
    /// Creates an ordinal from a non-negative vector.
    ///
    /// The vector represents a displacement from the origin. Only non-negative
    /// displacements correspond to valid ordinal positions.
    ///
    /// - Throws: `Ordinal.Error.underflow` if the vector is negative.
    @inlinable
    public init(_ vector: Affine.Discrete.Vector) throws(Ordinal.Error) {
        guard vector.rawValue >= 0 else { throw .underflow }
        self.init(UInt(vector.rawValue))
    }
}
```

#### Principled correctness

**Yes — this is principally sound.** It is the inverse of `Vector(ordinal) = ordinal - Origin`, subject to the constraint that vectors below the origin have no preimage. The throwing API correctly models the partiality:

```
f: Ordinal → Vector       (total, injective — exists)
f⁻¹: Vector → Ordinal     (partial — proposed)
f⁻¹(v) = v   when v ≥ 0
f⁻¹(v) = ⊥   when v < 0
```

The typed throw `Ordinal.Error.underflow` correctly classifies the failure mode. The caller at `Cyclic.Group+Arithmetic.swift:121` can use `try!` because the guard `offset.vector >= .zero` on line 120 ensures non-negativity.

### Recommendation

**Add `Ordinal(_ vector: Vector) throws(Ordinal.Error)` to ordinal-primitives.** This is the well-typed partial inverse of the existing total `Vector(_ ordinal:)` conversion.

**Location**: `swift-ordinal-primitives`, alongside existing `Ordinal` init overloads.

---

## Gap 3: `Vector.magnitude → Cardinal`

### Question

Is the absolute value of a signed displacement correctly typed as a Cardinal (unsigned count)?

### Analysis

#### Mathematical model

The **magnitude** (absolute value) of a vector is a scalar quantity: it answers "how far?" without direction. In the affine model:

- `Vector` ∈ ℤ (signed displacement)
- `|Vector|` ∈ ℕ (unsigned magnitude)
- `Cardinal` ∈ ℕ (unsigned quantity)

The magnitude of a displacement is a quantity — "how many units of distance?" This is precisely what Cardinal represents.

#### Existing usage

```swift
// Affine.Discrete+Arithmetic.swift:34 (Ordinal + Vector → Ordinal, negative branch)
let magnitude = rhs.vector.rawValue.magnitude
guard lhs.ordinal.rawValue >= magnitude else { throw .underflow }
return O(Ordinal(lhs.ordinal.rawValue - magnitude))
```

Here `Int.magnitude` returns `UInt` — the correct raw type for Cardinal. The code uses it as a quantity to subtract from an ordinal position.

```swift
// Cyclic.Group+Arithmetic.swift:125
let backward = Ordinal(offset.vector.rawValue.magnitude) % modulus.value
```

Same pattern: magnitude used as a quantity to compute modular arithmetic.

#### Proposed API

```swift
extension Affine.Discrete.Vector {
    /// The absolute value of this displacement as a cardinal quantity.
    ///
    /// The magnitude of a vector is the unsigned distance it represents,
    /// stripping direction information.
    @inlinable
    public var magnitude: Cardinal {
        Cardinal(rawValue.magnitude)
    }
}

// And the tagged variant:
extension Tagged where RawValue == Affine.Discrete.Vector, Tag: ~Copyable {
    /// The magnitude of this offset as an untagged cardinal.
    ///
    /// Note: The result is untagged because magnitude strips the directional
    /// semantics of the offset's phantom type. The caller must retag
    /// if needed.
    @inlinable
    public var magnitude: Cardinal {
        vector.magnitude
    }
}
```

#### Design decision: Tagged or untagged result?

When `Tagged<Bit, Vector>` (= `Index<Bit>.Offset`) has its magnitude taken, should the result be `Tagged<Bit, Cardinal>` (= `Index<Bit>.Count`) or bare `Cardinal`?

**Argument for tagged**: The magnitude of a bit-displacement is a bit-count. The domain tag is preserved.

**Argument for untagged**: Magnitude strips direction. The result is a scalar quantity whose domain depends on context. The caller should explicitly retag: `.magnitude.retag(Bit.self)` or use it untagged.

**Recommendation**: Provide **both** — untagged `magnitude` on `Vector`, and tagged `magnitude` on `Tagged<Tag, Vector>` returning `Tagged<Tag, Cardinal>`. The tagged version preserves the domain tag, which is the common case (bit offset magnitude → bit count).

#### Principled correctness

**Yes — this is principally sound.** The absolute value function `|·|: ℤ → ℕ` is a well-defined mathematical operation. Cardinal (ℕ) is the correct codomain. The only edge case is `Int.min`, whose magnitude (`Int.max + 1`) fits in `UInt` but is one more than `Int.max` — this is handled correctly by Swift's `Int.magnitude` returning `UInt`.

### Recommendation

**Add `Vector.magnitude → Cardinal` and `Tagged<Tag, Vector>.magnitude → Tagged<Tag, Cardinal>`.** This is the standard absolute value operation with the correct codomain type.

**Location**: `swift-affine-primitives`.

---

## Gap 4: `UnsafeRawPointer/Mutable(_ address: Memory.Address)`

### Question

Is constructing a raw pointer from a typed memory address principally correct?

### Analysis

#### Current state

This conversion **already exists** in memory-primitives:

```swift
// Memory.Address.swift:135-141
extension UnsafeRawPointer {
    @inlinable
    public init(_ address: Memory.Address) {
        unsafe self = UnsafeRawPointer(bitPattern: address.rawValue.rawValue)!
    }
}

// Memory.Address.swift:143-149
extension UnsafeMutableRawPointer {
    @inlinable
    public init(_ address: Memory.Address) {
        unsafe self = UnsafeMutableRawPointer(bitPattern: address.rawValue.rawValue)!
    }
}
```

#### Why it was listed as deferred

The deferred list appears to have been generated before verifying the existing codebase. Both conversions already exist. The force-unwrap `!` is safe because `Memory.Address` is defined as `Tagged<Memory, Ordinal>`, and the `Ordinal` stores a `UInt` bit pattern. Construction from a non-null pointer guarantees non-zero bit pattern, so `UnsafeRawPointer(bitPattern:)` never returns nil.

#### Principled correctness

**Yes — already implemented correctly.** The round-trip is:

```
UnsafeRawPointer → UInt (bitPattern) → Ordinal → Tagged<Memory, Ordinal> = Address
Address → Ordinal → UInt → UnsafeRawPointer (bitPattern, non-null guaranteed)
```

The conversion preserves the bit pattern exactly. The non-null invariant is maintained by the type system (`Memory.Address` cannot be constructed from a null pointer — the optional-pointer init throws `.null`).

**Provenance note**: As documented in `Memory.Address.swift`, this uses an integer-address model. Pointer provenance is not preserved through the `Memory.Address` layer. This is a deliberate design decision, documented as such.

### Recommendation

**No action needed.** This gap does not exist — the infrastructure is already in place.

---

## Gap 5: Bounded/Inline Equality/Hash Loops

### Question

The Bounded and Inline equality/hash implementations require iterating "the first N words" where N is computed at runtime from `Bit.Pack`. Is there a typed way to express this without escaping to `Int`?

### Analysis

#### Current code

```swift
// Bit.Vector.Bounded+protocols.swift:16-24
public static func == (lhs: Self, rhs: Self) -> Bool {
    guard lhs._count == rhs._count else { return false }
    let pack = Bit.Pack<UInt>(count: lhs._count, bitsPerWord: .bitsPerWord)
    let wordCount = Int(bitPattern: pack.words.count)
    for i in 0..<wordCount {
        if lhs._storage[i] != rhs._storage[i] { return false }
    }
    return true
}
```

`pack.words.count` is `Index<UInt>.Count` (= `Tagged<UInt, Cardinal>`). The `Int(bitPattern:)` is needed because:
1. `for i in 0..<wordCount` requires `Int` for the range
2. `_storage[i]` uses `ContiguousArray` subscript which takes `Int`

#### Why Inline is different

```swift
// Bit.Vector.Inline+protocols.swift:16-22
public static func == (lhs: Self, rhs: Self) -> Bool {
    guard lhs._count == rhs._count else { return false }
    for i in 0..<wordCount {
        if lhs._storage[i] != rhs._storage[i] { return false }
    }
    return true
}
```

Inline uses the compile-time generic parameter `wordCount: Int` directly. Since both sides have the same `<let wordCount: Int>`, all words are meaningful (the count guard ensures semantic equality). No `Int(bitPattern:)` needed — this is **already solved**.

#### Options for Bounded

**Option A: Typed while loop with ordinal subscript**

```swift
var w: Index<UInt> = .zero
let end = pack.words.count.map(Ordinal.init)
while w < end {
    if lhs._storage[w] != rhs._storage[w] { return false }
    w += .one
}
```

This requires `ContiguousArray.subscript(position: O) where O: Ordinal.Protocol` (already exists in ordinal-primitives).

**Pros**: Fully typed. No `Int(bitPattern:)`.
**Cons**: Slightly more verbose than `for i in 0..<n`.

**Option B: Iterate via prefix**

```swift
for (l, r) in zip(lhs._storage.prefix(pack.words.count), rhs._storage.prefix(pack.words.count)) {
    if l != r { return false }
}
```

This requires `ContiguousArray.prefix(_ count: C) where C: Cardinal.Protocol` — does not currently exist.

**Option C: Leave as is**

The `Int(bitPattern:)` is a legitimate boundary conversion (Category E in the audit). The loop index is consumed by `ContiguousArray` subscript (stdlib API), which mandates `Int`. This is an inherent boundary, not an infrastructure gap.

#### Principled analysis

The loop pattern `for i in 0..<wordCount` where `wordCount` comes from a Cardinal is a **stdlib boundary**. The `Int(bitPattern:)` here is not escaping typed arithmetic — it's crossing the boundary to stdlib's `Int`-based collection API. Per [IMPL-010], this belongs in a boundary overload, not at the call site.

However, if the `ContiguousArray` ordinal subscript already exists, Option A eliminates the boundary entirely by never entering `Int` space.

### Recommendation

**Option A (typed while loop)** for Bounded equality and hash. The ordinal subscript on `ContiguousArray` already exists in ordinal-primitives, so no new infrastructure is needed — this is a call-site improvement using existing infrastructure.

The Inline case is already clean (compile-time `wordCount` parameter).

---

## Outcome

**Status**: DECISION

### Summary Table

| # | Gap | Principled? | Action | Location | Depends On |
|---|-----|-------------|--------|----------|------------|
| 1 | `<< / >> Cardinal.Protocol` | Yes — Cardinal is the mathematically correct type for shift counts (ℕ-indexed endomorphisms on Word) | Bare operators in bit-primitives (tier 9); Tagged variants in binary-primitives (tier 14) | bit-primitives + binary-primitives | Gap 3 |
| 2 | `Ordinal(_ vector: Vector) throws` | **Yes** — partial inverse of existing `Vector(ordinal:)` | Added throwing init | affine-primitives (ordinal-primitives lacks affine dependency) | None |
| 3 | `Vector.magnitude → Cardinal` | **Yes** — absolute value ℤ → ℕ is standard | Added property on both Vector and Tagged variant | affine-primitives | None |
| 4 | `UnsafeRawPointer(_ address:)` | **Already exists** | No action | memory-primitives | — |
| 5 | Bounded/Inline equality loops | Inline already clean; Bounded uses existing ordinal subscript | Converted Bounded to typed while loop (Option A) | bit-vector-primitives | None |

### Dependency graph

```
Gap 3 (Vector.magnitude → Cardinal)
  └── Gap 1 Option A (FixedWidthInteger << Cardinal.Protocol)

Gap 2 (Ordinal(Vector)) ← independent
Gap 4 ← already done
Gap 5 ← already possible with existing infrastructure
```

### Implementation order

1. **Gap 4**: Verify — no work needed.
2. **Gap 5**: Bounded typed while loop — uses existing ordinal subscript infrastructure.
3. **Gap 2**: `Ordinal(_ vector:)` — independent, straightforward.
4. **Gap 3**: `Vector.magnitude → Cardinal` — independent, straightforward.
5. **Gap 1**: Shift operators — decide Cardinal vs Vector after Gaps 2-3 settle.

### Open question for Gap 1

The shift operator gap has a genuine tension between mathematical correctness (Cardinal — shift is a count) and pragmatic fit (Vector — call sites hold Offsets, stdlib uses signed Int). This tension cannot be resolved by analysis alone. Recommend:

- If the project prioritizes **mathematical purity**: use Cardinal, accept the Offset→Cardinal conversion at call sites (trivial after Gap 3).
- If the project prioritizes **zero-friction call sites**: use Vector, accept the semantic imprecision (a shift "amount" typed as a "displacement").
- If the project prioritizes **stdlib alignment**: keep `Int`, add boundary overloads that accept Vector/Cardinal and convert internally.

## References

- `int-bitpattern-conversion-audit.md` — ecosystem-wide Int(bitPattern:) audit
- `Tagged+Bitwise.swift` — existing shift operators in binary-primitives
- `Tagged+Affine.swift` — affine arithmetic operators
- `Affine.Discrete+Arithmetic.swift` — Position + Vector implementation
- `Memory.Address.swift` — Address ↔ pointer conversions
- `Bit.Pack.Location.swift` — deferred shift sites
- `Bit.Vector.Bounded+protocols.swift` — equality/hash loop pattern
