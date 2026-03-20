# swift-ordering-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Audited against**: [API-NAME-001], [API-NAME-002], [IMPL-INTENT], [API-IMPL-005]
**Status**: READ-ONLY audit

## Summary Table

| ID | Severity | Rule | Location | Finding |
|----|----------|------|----------|---------|
| [ORD-001] | HIGH | [API-NAME-001] | `Ordering.PartialComparator` | Compound type name `PartialComparator` |
| [ORD-002] | MEDIUM | [API-NAME-002] | `Ordering.Comparator+Projection.swift` | Compound-adjacent static factory `.by(_:using:)` — acceptable but noted |
| [ORD-003] | MEDIUM | [API-NAME-002] | `Ordering.Order+Property.View.swift:25,41,60` | Compound method names `isBefore`, `isAfter`, `isEquivalent` |
| [ORD-004] | MEDIUM | [API-NAME-002] | `Ordering.Order+Swift.Comparable.swift:35,50,65` | Same compound methods duplicated for `Swift.Comparable` |
| [ORD-005] | LOW | [API-NAME-002] | `Ordering.Comparator+Chaining.swift:51` | `then(with:)` label is mechanism-leaking; `then` alone is fine |
| [ORD-006] | INFO | [API-IMPL-005] | `Ordering.Orderable+Swift.Comparable.swift` | 14 retroactive conformances in one file — acceptable for conformance-only files |
| [ORD-007] | INFO | [API-IMPL-005] | `Ordering.Order+Swift.Comparable.swift` | Mixed content: `Property.View` extension + `Swift.Comparable` extension + `.order` property — 2 logically distinct extensions in one file |
| [ORD-008] | INFO | [IMPL-INTENT] | `Ordering.Comparator+Swift.Comparable.swift:25` | `init(swift: Void)` — mechanism-leaking disambiguation initializer |
| [ORD-009] | INFO | [IMPL-INTENT] | `Ordering.Order+Property.View.swift:29,45,64` | `unsafe base.pointee` — raw pointer access reads as mechanism, not intent |

---

## Detailed Findings

### [ORD-001] Compound type name `PartialComparator` — HIGH

**Rule**: [API-NAME-001] All types MUST use `Nest.Name` pattern. Compound type names FORBIDDEN.

**File**: `Sources/Ordering Primitives/Ordering.PartialComparator.swift:35`

**Current**:
```swift
public struct PartialComparator<T: ~Copyable>: Sendable
```

**Problem**: `PartialComparator` is a compound name joining `Partial` + `Comparator`. Per [API-NAME-001], this should be decomposed into a nested type.

**Suggested structure**:
```swift
// Option A: Ordering.Comparator.Partial<T>
extension Ordering.Comparator where T: ~Copyable {
    public struct Partial: Sendable { ... }
}

// Option B: Ordering.Partial.Comparator<T>  (if Partial is a broader concept)
```

Option A is preferred because `Partial` qualifies the `Comparator` — it is a variant of comparator that may return `nil`. The nesting `Ordering.Comparator.Partial` reads as "an ordering comparator that is partial."

**Impact**: The type is referenced in the namespace doc comment (`Ordering.swift:21`) and in any downstream consumers.

---

### [ORD-002] Static factory `.by(_:using:)` — MEDIUM

**Rule**: [API-NAME-002] Methods MUST NOT use compound names.

**File**: `Sources/Ordering Primitives/Ordering.Comparator+Projection.swift:56`

**Current**:
```swift
public static func by<Value: ~Copyable>(
    _ selector: @escaping @Sendable (borrowing T) -> Value,
    using comparator: Ordering.Comparator<Value>
) -> Ordering.Comparator<T>
```

**Assessment**: `.by` is a single word, not compound. The `using:` label is standard Swift API Guidelines for a tool/strategy parameter. This is **acceptable** but noted for completeness. No action needed.

---

### [ORD-003] Compound method names `isBefore`, `isAfter`, `isEquivalent` — MEDIUM

**Rule**: [API-NAME-002] Methods/properties MUST NOT use compound names. Use nested accessors.

**File**: `Sources/Ordering Primitives/Ordering.Order+Property.View.swift:25,41,60`

**Current** (9 methods total across 2 files, 3 in this file with `by:` parameter, 3 without):
```swift
func isBefore(_ other: borrowing Base, by comparator: ...) -> Bool
func isAfter(_ other: borrowing Base, by comparator: ...) -> Bool
func isEquivalent(to other: borrowing Base, by comparator: ...) -> Bool
```

**Problem**: `isBefore`, `isAfter`, and `isEquivalent` are compound identifiers. Under strict [API-NAME-002], these should use nested accessors.

**Possible decomposition**:
```swift
// Nested accessor pattern
value.order.is.before(other, by: comparator)
value.order.is.after(other, by: comparator)
value.order.is.equivalent(to: other, by: comparator)
```

**Tension**: This is a case where the compound form (`isBefore`) is highly idiomatic in Swift (cf. `Collection.isEmpty`, `FloatingPoint.isNaN`). The stdlib uses `is`-prefixed compound predicates extensively. Decomposing to `is.before` would create a non-standard accessor chain for a boolean predicate.

**Recommendation**: Flag for design discussion. The `is`-prefix boolean predicate pattern may warrant an explicit carve-out in [API-NAME-002], or these methods should be decomposed. The 9 compound methods (3 with `by:` + 3 without in `Property.View`, plus 3 in `Swift.Comparable`) are the core of the finding the user flagged.

---

### [ORD-004] Same compound methods duplicated for `Swift.Comparable` — MEDIUM

**Rule**: [API-NAME-002]

**File**: `Sources/Ordering Primitives/Ordering.Order+Swift.Comparable.swift:35,50,65`

**Current**:
```swift
public func isBefore(_ other: Base) -> Bool
public func isAfter(_ other: Base) -> Bool
public func isEquivalent(to other: Base) -> Bool
```

Same compound name issue as [ORD-003], duplicated in the `Swift.Comparable` convenience extension. Any rename applied to [ORD-003] must be applied here as well.

---

### [ORD-005] `then(with:)` label — LOW

**Rule**: [API-NAME-002]

**File**: `Sources/Ordering Primitives/Ordering.Comparator+Chaining.swift:51`

**Current**:
```swift
public func then(with other: @escaping @Sendable () -> Ordering.Comparator<T>) -> Ordering.Comparator<T>
```

**Assessment**: `then` is a single word (fine). The `with:` label differentiates the lazy variant from the eager `then(_:)`. However, the name `with` is mechanism-leaking — it describes *how* the secondary comparator is provided (via closure), not *what* it means. Consider `then(lazy:)` or `then(deferred:)` to express intent. Alternatively, the lazy variant could be the only overload if the compiler can distinguish `Ordering.Comparator<T>` from `() -> Ordering.Comparator<T>`.

---

### [ORD-006] 14 retroactive conformances in one file — INFO

**Rule**: [API-IMPL-005] One type per file.

**File**: `Sources/Ordering Primitives/Ordering.Orderable+Swift.Comparable.swift`

**Assessment**: This file contains 14 retroactive `Ordering.Orderable` conformances for stdlib types (`Int`, `UInt`, `Int8`, ..., `String`, `Double`, `Float`, `Character`). These are conformance-only extensions (no body), not type declarations. [API-IMPL-005] targets type *declarations*. Grouping conformance-only retroactive extensions in a single file is a recognized pattern and acceptable.

---

### [ORD-007] Mixed extensions in one file — INFO

**Rule**: [API-IMPL-005]

**File**: `Sources/Ordering Primitives/Ordering.Order+Swift.Comparable.swift`

**Assessment**: This file contains two logically distinct extensions:
1. `Property.View where Tag == Ordering.Order, Base: Swift.Comparable` (lines 22-68) — ordering methods
2. `Swift.Comparable where Self: Copyable` (lines 85-96) — `.order` property

Both serve the same purpose (bridging `Swift.Comparable` to the ordering API), so co-location is defensible. The second extension could be separated into `Ordering.Orderable+Swift.Comparable.swift` alongside the other stdlib conformances. Minor.

---

### [ORD-008] `init(swift: Void)` disambiguation — INFO

**Rule**: [IMPL-INTENT]

**File**: `Sources/Ordering Primitives/Ordering.Comparator+Swift.Comparable.swift:25`

**Current**:
```swift
public init(swift: Void) {
    self.init { lhs, rhs in
        Comparison(comparing: lhs, to: rhs)
    }
}
```

**Assessment**: The `swift:` label with `Void` argument is used to disambiguate from the `Comparison.Protocol` `init()`. This is a known pattern for avoiding overload ambiguity. The mechanism is visible at the call site: `Ordering.Comparator<String>(swift: ())`. The `swift: ()` reads oddly but has clear semantic intent (use Swift's `Comparable`). Low priority; the primary API is `.ascending`/`.descending` which hide this initializer.

---

### [ORD-009] `unsafe base.pointee` in Property.View methods — INFO

**Rule**: [IMPL-INTENT]

**File**: `Sources/Ordering Primitives/Ordering.Order+Property.View.swift:29,45,64`

**Current**:
```swift
unsafe comparator(base.pointee, other).isLess
unsafe comparator(base.pointee, other).isGreater
unsafe comparator(base.pointee, other).isEqual
```

**Assessment**: The `unsafe` keyword and `base.pointee` are mechanism-level details of the `Property.View` infrastructure. This is inherent to how `Property.View` works (it holds an `UnsafeMutablePointer` to `Base`). The unsafety is confined to the infrastructure boundary and not exposed to consumers. No action needed — this is the correct pattern for `Property.View` extensions.

---

## Statistics

| Metric | Count |
|--------|-------|
| Source files | 16 (including exports.swift) |
| Types declared | 6 (Ordering, Order, Comparator, PartialComparator, Projection, Direction) + 1 protocol (Orderable) |
| Compound type names | 1 (`PartialComparator`) |
| Compound method names | 9 (3 methods x 3 extension sites) |
| HIGH findings | 1 |
| MEDIUM findings | 3 |
| LOW findings | 1 |
| INFO findings | 4 |
