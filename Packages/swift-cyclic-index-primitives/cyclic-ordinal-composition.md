# Cyclic Group Element as Ordinal Composition

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
---
-->

## Context

During the extraction of `swift-cyclic-index-primitives`, a deeper architectural question emerged: Can `Cyclic.Group<N>.Element` be expressed compositionally using the existing Ordinal/Cardinal/Affine primitives rather than implementing its own arithmetic from scratch?

The current implementation uses `Int` as the raw value and implements modular arithmetic directly. This works but misses an opportunity for structural reuse and semantic alignment with the rest of the primitives type system.

## Question

Should `Cyclic.Group<N>.Element` use `Ordinal` as its underlying representation and express cyclic arithmetic in terms of Ordinal/Cardinal operations?

## Analysis

### Current Implementation

**Location:** `swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.swift`

```swift
public struct Element: Hashable, Comparable, Sendable {
    public let rawValue: Int  // Stores values in [0, order)

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), (lhs.rawValue + rhs.rawValue) % order)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), ((lhs.rawValue - rhs.rawValue) % order + order) % order)
    }
}
```

**Issues with current design:**
1. Uses `Int` despite values always being non-negative
2. Implements arithmetic from scratch rather than reusing primitives
3. The `((a - b) % n + n) % n` formula is a workaround for signed modulo behavior
4. No structural connection to Ordinal (positions) or Cardinal (counts)

### Proposed Implementation

**Core insight:** Cyclic subtraction `a - b (mod N)` equals `a + (N - b) (mod N)`.

This means ALL cyclic arithmetic can be expressed using:
- `Ordinal + Cardinal` (addition)
- `Cardinal - Cardinal` (computing inverse)
- `Ordinal % Cardinal` (modular reduction)

```swift
public struct Element: Hashable, Comparable, Sendable {
    /// The position within the cyclic group [0, order).
    public let position: Ordinal

    /// The group order as a Cardinal for arithmetic operations.
    @inlinable
    public static var orderCardinal: Cardinal { Cardinal(UInt(order)) }

    // MARK: - Construction

    @inlinable
    public init(_ value: Int) throws(Error) {
        guard order > 0 else { throw .invalidOrder }
        guard value >= 0, value < order else { throw .outOfBounds(value) }
        self.position = Ordinal(UInt(value))
    }

    @inlinable
    public init(__unchecked: Void, _ value: Int) {
        self.position = Ordinal(UInt(value))
    }

    @inlinable
    public init(position: Ordinal) throws(Error) {
        guard order > 0 else { throw .invalidOrder }
        guard position.rawValue < UInt(order) else {
            throw .outOfBounds(Int(position.rawValue))
        }
        self.position = position
    }

    @inlinable
    public init(wrapping position: Ordinal) {
        precondition(order > 0, "Cyclic group order must be positive")
        self.position = position % Self.orderCardinal
    }

    // MARK: - Raw Value Access (for compatibility)

    /// The underlying value as Int (for API compatibility).
    @inlinable
    public var rawValue: Int { Int(position.rawValue) }
}
```

### Arithmetic Implementation

```swift
extension Cyclic.Group.Element {
    // MARK: - Identity Elements

    @inlinable
    public static var zero: Self {
        Self(__unchecked: (), 0)
    }

    @inlinable
    public static var one: Self {
        Self(__unchecked: (), order > 1 ? 1 : 0)
    }

    // MARK: - Addition (uses Ordinal + Cardinal + modulo)

    @inlinable
    public static func + (lhs: Self, rhs: Self) -> Self {
        // Ordinal + Cardinal -> Ordinal, then reduce
        let sum = lhs.position + Cardinal(rhs.position.rawValue)
        return Self(wrapping: sum)
    }

    // MARK: - Subtraction (uses addition of inverse)

    /// Cyclic subtraction: a - b = a + (N - b)
    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Self {
        // Compute additive inverse: N - b
        let inverse = Self.orderCardinal - Cardinal(rhs.position.rawValue)
        // Add inverse: a + (N - b)
        let sum = lhs.position + inverse
        // Reduce modulo N
        return Self(wrapping: sum)
    }

    // MARK: - Compound Assignment

    @inlinable
    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    @inlinable
    public static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }

    // MARK: - Additive Inverse

    /// The additive inverse such that `a + a.inverse == .zero`.
    @inlinable
    public var inverse: Self {
        if position.rawValue == 0 {
            return self
        }
        // inverse of a is N - a
        let inv = Self.orderCardinal - Cardinal(position.rawValue)
        return Self(__unchecked: (), Int(inv.rawValue))
    }
}
```

### Verification of Arithmetic Correctness

**Addition:** `(2 + 5) mod 7`
- `Ordinal(2) + Cardinal(5) = Ordinal(7)`
- `Ordinal(7) % Cardinal(7) = Ordinal(0)` ✓

**Subtraction:** `(2 - 5) mod 7 = -3 mod 7 = 4`
- Inverse of 5: `Cardinal(7) - Cardinal(5) = Cardinal(2)`
- Sum: `Ordinal(2) + Cardinal(2) = Ordinal(4)`
- Result: `4` ✓

**Edge case:** `(0 - 1) mod 5 = 4`
- Inverse of 1: `Cardinal(5) - Cardinal(1) = Cardinal(4)`
- Sum: `Ordinal(0) + Cardinal(4) = Ordinal(4)`
- Result: `4` ✓

### Dependency Changes

**Before:**
```
swift-cyclic-primitives
├── swift-comparison-primitives (Tier 2)
├── swift-hash-primitives (Tier 3)
└── swift-sequence-primitives (Tier 7)
```

**After:**
```
swift-cyclic-primitives
├── swift-comparison-primitives (Tier 2)
├── swift-hash-primitives (Tier 3)
├── swift-ordinal-primitives (Tier 4)
├── swift-cardinal-primitives (Tier 3)
└── swift-sequence-primitives (Tier 7)
```

**Tier impact:** None. Cyclic-primitives remains at Tier 8. All new dependencies are lower tiers.

### API Changes

| Aspect | Before | After | Breaking? |
|--------|--------|-------|-----------|
| `rawValue` type | `Int` | `Int` (computed from `position`) | No |
| `position` property | N/A | `Ordinal` (new) | Additive |
| Construction | `init(_ rawValue: Int)` | Same signature | No |
| Wrapping init | `init(wrapping: Ordinal)` | Same | No |
| Arithmetic results | Same values | Same values | No |
| `Hashable` | Via `rawValue: Int` | Via `position: Ordinal` | No* |
| `Comparable` | Via `rawValue: Int` | Via `position: Ordinal` | No* |

*Hash values may differ, but semantic equality is preserved.

### Files to Modify

**swift-cyclic-primitives:**

1. **Package.swift** — Add ordinal/cardinal dependencies
2. **Cyclic.Group.swift** — Change `rawValue: Int` to `position: Ordinal`
3. **Cyclic.Group+Arithmetic.swift** — Reimplement using Ordinal/Cardinal ops
4. **Cyclic.Group.Element+Ordinal.Position.swift** — Simplify (position is now Ordinal)
5. **Cyclic.Group.Iterator.swift** — Use Ordinal for iteration state
6. **exports.swift** — Add Ordinal/Cardinal re-exports

**swift-cyclic-primitives tests:**

1. **CyclicGroupTests.swift** — Update assertions (`.rawValue` still works)

**swift-cyclic-index-primitives:**

1. No changes needed — delegates to underlying arithmetic

### Comparison Table

| Criterion | Current (Int) | Proposed (Ordinal) |
|-----------|---------------|-------------------|
| Structural reuse | None | Full (Ordinal + Cardinal) |
| Semantic alignment | Implicit | Explicit (position in bounded space) |
| Code complexity | Simple formula | Compositional operations |
| Dependencies | 3 packages | 5 packages |
| Performance | Direct % | Multiple ops (likely same after inlining) |
| Type safety | Int allows negatives | Ordinal enforces non-negative |
| Arithmetic correctness | Proven | Proven (same results) |

## Outcome

**Status:** RECOMMENDATION

**Recommendation:** Refactor `Cyclic.Group<N>.Element` to use `Ordinal` as its underlying representation.

**Rationale:**

1. **Principled composition**: Cyclic arithmetic becomes a composition of existing primitives rather than a parallel implementation.

2. **Semantic clarity**: A cyclic group element IS a bounded position — using `Ordinal` makes this explicit.

3. **Type safety**: `Ordinal` enforces non-negativity at the type level; `Int` allows invalid negative intermediate values.

4. **Structural consistency**: Aligns with how `Index`, `Index.Offset`, and `Index.Count` all compose with Ordinal/Cardinal/Affine.

5. **Future extensibility**: Opens the door for mixed operations like `Cyclic.Group<N>.Element + Cardinal` or integration with Affine vectors.

**Implementation priority:** Medium — This is a correct architectural improvement but not blocking current work.

## Implementation Plan

### Phase 1: Update swift-cyclic-primitives

1. Add dependencies to Package.swift:
   ```swift
   .package(path: "../swift-ordinal-primitives"),
   .package(path: "../swift-cardinal-primitives"),
   ```

2. Rewrite `Cyclic.Group.Element`:
   - Change storage from `rawValue: Int` to `position: Ordinal`
   - Add computed `rawValue: Int` for backward compatibility
   - Add `orderCardinal` static property

3. Rewrite arithmetic in `Cyclic.Group+Arithmetic.swift`:
   - Addition: `position + Cardinal + % Cardinal`
   - Subtraction: `position + (orderCardinal - Cardinal) + % Cardinal`
   - Inverse: `orderCardinal - Cardinal`

4. Simplify `Cyclic.Group.Element+Ordinal.Position.swift`:
   - `init(position: Ordinal)` becomes primary
   - Conversion to Ordinal is trivial (return `position`)

5. Update Iterator to use Ordinal

6. Update exports.swift

### Phase 2: Update Tests

1. Update CyclicGroupTests.swift — most tests should pass unchanged due to `rawValue` compatibility

2. Add new tests for Ordinal-based construction

### Phase 3: Verify Downstream

1. Rebuild swift-cyclic-index-primitives — should work unchanged
2. Run all tests

## References

- `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift`
- `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.swift`
- `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group+Arithmetic.swift`
