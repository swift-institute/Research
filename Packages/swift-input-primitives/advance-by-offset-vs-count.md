# Research: advance(by: Offset) vs advance(by: Count)

<!--
---
version: 2.0.0
last_updated: 2026-01-29
status: SUPERSEDED
superseded_by: /swift-primitives/Research/typed-index-arithmetic-unification.md
package: swift-input-primitives
affects: [swift-input-primitives]
tags: [api-design, type-safety, totality]
---
-->

> **SUPERSEDED**: This research led to a broader refactor. See `typed-index-arithmetic-unification.md` for the final design where `Input.Buffer` and `Input.Slice` store typed `Index<Element>` as the primary representation, enabling pure typed arithmetic throughout.

## Context

In `swift-input-primitives`, the `Input.Protocol` defines a conformance primitive:

```swift
// Input.Protocol.swift:100-105
/// Advances the cursor by the given offset.
///
/// - Precondition: `offset >= .zero && offset < count`
///
/// > Note: Conformance primitive. Use `remove.first(_:)` for validated API.
mutating func advance(by offset: Index<Element>.Offset)
```

**Observation**: The precondition requires `offset >= .zero`, meaning negative values are forbidden. Yet the parameter type is `Index<T>.Offset` (which CAN represent negative values via `Affine.Discrete.Vector`), not `Index<T>.Count` (which is inherently non-negative via `Cardinal`).

## Question

Should `Input.Protocol.advance(by:)` take `Index<T>.Offset` or `Index<T>.Count`?

## Type Definitions (Reference)

From the swift-index-primitives and swift-affine-primitives packages:

| Type | Definition | Representable Values |
|------|------------|---------------------|
| `Index<T>.Offset` | `Tagged<T, Affine.Discrete.Vector>` | Signed integers: `Int.min...Int.max` |
| `Index<T>.Count` | `Tagged<T, Cardinal>` | Non-negative integers: `0...UInt.max` |

The key difference:
- **Offset**: Displacement between positions (can be negative for backward movement)
- **Count**: Cardinality (quantity) — inherently non-negative by construction

## Current Usage Analysis

### Call Sites

The only call sites in `Input.Remove.swift:83,91`:

```swift
// Input.Remove.swift:78-84
public func first(_ count: Index<Base.Element>.Count) throws(Input.Remove.Error<Base.Element>) {
    let available = unsafe base.pointee.count
    guard count <= available else {
        throw .insufficientElements(requested: count, available: available)
    }
    unsafe base.pointee.advance(by: Index<Base.Element>.Offset(count))  // ← Conversion here
}

// Input.Remove.swift:86-92
public func first(__unchecked: Void, _ count: Index<Base.Element>.Count) {
    unsafe base.pointee.advance(by: Index<Base.Element>.Offset(count))  // ← Conversion here
}
```

**Finding**: Both call sites receive a `Count` parameter and convert it to `Offset` before calling `advance(by:)`.

### Implementations

```swift
// Input.Buffer+Input.Protocol.swift:65-67
public mutating func advance(by offset: Index<Element>.Offset) {
    position = storage.index(position, offsetBy: offset)
}

// Input.Slice+Input.Protocol.swift:63-65
public mutating func advance(by offset: Index<Element>.Offset) {
    startIndex = base.index(startIndex, offsetBy: offset)
}
```

**Finding**: Both implementations delegate to `Collection.index(_:offsetBy:)` which takes `Int` (via implicit conversion).

## Options

### Option A: Keep `advance(by: Offset)` with precondition

**Current design.** The primitive accepts the general type, with a runtime precondition ensuring non-negativity.

```swift
/// - Precondition: `offset >= .zero && offset < count`
mutating func advance(by offset: Index<Element>.Offset)
```

### Option B: Change to `advance(by: Count)` for type safety

**Alternative.** The primitive accepts only the restricted type that matches the precondition.

```swift
/// - Precondition: `count <= self.count`
mutating func advance(by count: Index<Element>.Count)
```

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Totality | High | Are preconditions expressible as types? |
| Caller convenience | Medium | What conversion burden falls on call sites? |
| Semantic accuracy | High | Does the type match the operation's meaning? |
| Conformance simplicity | Medium | Is implementation straightforward? |
| Future extensibility | Low | Does it support potential negative offsets? |

## Analysis

### Totality

**Option A (Offset)**: Precondition `offset >= .zero` is NOT enforced by the type. A caller can pass `-5` and violate the precondition at runtime.

**Option B (Count)**: Precondition `count >= .zero` IS enforced by the type. `Cardinal` cannot represent negative values, so the type system prevents this error class entirely.

**Winner**: Option B — aligns with [API-IMPL-003] preference for totality.

### Caller Convenience

**Option A (Offset)**: Call sites with `Count` must convert:
```swift
advance(by: Index<Element>.Offset(count))  // Current conversion
```

**Option B (Count)**: Call sites with `Count` pass directly:
```swift
advance(by: count)  // No conversion needed
```

Both call sites in the codebase have `Count` values. The conversion `Index<T>.Offset(count)` is total (cardinals are always non-negative), but it's boilerplate.

**Winner**: Option B — eliminates conversion at all current call sites.

### Semantic Accuracy

**Option A (Offset)**: "Offset" implies displacement between two positions. Semantic model: `position2 - position1 → offset`. Offsets answer "how far did we move?" and can be negative.

**Option B (Count)**: "Count" implies quantity. Semantic model: `|elements|`. Counts answer "how many elements?" and are inherently non-negative.

The operation is "advance the cursor by N elements." The question being asked is "how many elements to skip?" — that's a **quantity**, not a displacement.

Compare with:
- `Collection.index(_:offsetBy:)` — takes `Int` (signed) because it supports backward iteration via negative offsets
- `Collection.dropFirst(_:)` — takes `Int` but semantically represents a count; Swift's stdlib uses `Int` for legacy reasons

**Winner**: Option B — "advance by N elements" is a count operation.

### Conformance Simplicity

**Option A (Offset)**:
```swift
public mutating func advance(by offset: Index<Element>.Offset) {
    position = storage.index(position, offsetBy: offset)  // Needs Int conversion
}
```

**Option B (Count)**:
```swift
public mutating func advance(by count: Index<Element>.Count) {
    position = storage.index(position, offsetBy: Int(bitPattern: count))  // Needs Int conversion
}
```

Both require conversion to `Int` for the stdlib call. The conversion path differs slightly:
- Offset → Int: `offset.rawValue.rawValue` (signed → signed)
- Count → Int: `Int(bitPattern: count.rawValue.rawValue)` (unsigned → signed bitcast)

**Neutral** — both need conversion; complexity is comparable.

### Future Extensibility

**Option A (Offset)**: If `Input.Protocol` ever needed backward iteration, `advance(by: Offset)` would support it without API change.

**Option B (Count)**: Backward iteration would require a separate method like `retreat(by: Count)` or changing the signature.

**However**: The protocol documentation explicitly states "forward iteration only":
> This protocol does not require random access - only forward iteration with the ability to save and restore positions.

And `setPosition(to:)` already provides backtracking via checkpoint restoration, not negative offsets.

**Winner**: Option A — but this is speculative future-proofing with low weight.

### Summary

| Criterion | Option A (Offset) | Option B (Count) |
|-----------|-------------------|------------------|
| Totality | Runtime precondition | Type-enforced |
| Caller convenience | Requires conversion | Direct |
| Semantic accuracy | Displacement (wrong) | Quantity (correct) |
| Conformance simplicity | Comparable | Comparable |
| Future extensibility | Supports negative | Would need new method |

## Recommendation

**RECOMMENDED: Option B — Change to `advance(by: Count)`**

**Rationale**:

1. **Type-enforced precondition**: The `offset >= .zero` precondition becomes statically guaranteed. Callers cannot pass negative values because `Count` cannot represent them. This aligns with Swift Institute's preference for totality over runtime checks.

2. **Semantic correctness**: "Advance by N elements" is asking "how many?" — a cardinality question. Using `Count` matches the semantic intent.

3. **Call site improvement**: Both existing call sites have `Count` values. Eliminating the `Index<T>.Offset(count)` conversion removes boilerplate and reduces cognitive load.

4. **Precondition simplification**: The precondition changes from `offset >= .zero && offset <= count` to just `count <= self.count`. The non-negativity constraint is absorbed into the type.

5. **Principled consistency**: The `count` property already returns `Index<Element>.Count`. Using `Count` for the parameter creates symmetry: `advance(by: count)` where `count <= self.count`.

## Implementation

### Protocol Change

```swift
// Input.Protocol.swift
/// Advances the cursor by the given count.
///
/// - Precondition: `count <= self.count`
///
/// > Note: Conformance primitive. Use `remove.first(_:)` for validated API.
mutating func advance(by count: Index<Element>.Count)
```

### Conformance Updates

```swift
// Input.Buffer+Input.Protocol.swift
@inlinable
public mutating func advance(by count: Index<Element>.Count) {
    position = storage.index(position, offsetBy: Int(bitPattern: count))
}

// Input.Slice+Input.Protocol.swift
@inlinable
public mutating func advance(by count: Index<Element>.Count) {
    startIndex = base.index(startIndex, offsetBy: Int(bitPattern: count))
}
```

### Call Site Updates

```swift
// Input.Remove.swift:78-84 — no change needed, already passes Count
public func first(_ count: Index<Base.Element>.Count) throws(Input.Remove.Error<Base.Element>) {
    let available = unsafe base.pointee.count
    guard count <= available else {
        throw .insufficientElements(requested: count, available: available)
    }
    unsafe base.pointee.advance(by: count)  // ← Conversion removed
}

// Input.Remove.swift:86-92 — no change needed
public func first(__unchecked: Void, _ count: Index<Base.Element>.Count) {
    unsafe base.pointee.advance(by: count)  // ← Conversion removed
}
```

## Migration Impact

- **Source-breaking**: Yes — conforming types must update their signature
- **ABI-breaking**: Yes — parameter type changes
- **Effort**: Low — only two conformances exist, both in-package

Since `swift-input-primitives` is pre-1.0 and internal, this is the right time to make the change.

## References

- `Input.Protocol.swift:100-105` — protocol definition
- `Input.Remove.swift:78-92` — call sites
- `Input.Buffer+Input.Protocol.swift:65-67` — Buffer conformance
- `Input.Slice+Input.Protocol.swift:63-65` — Slice conformance
- `Index.Count.swift` — Count type definition
- `Index.Offset.swift` — Offset type definition
- `Tagged+Affine.swift:65-67` — Count→Offset total conversion
- `Affine.Discrete.Displacement.swift` — Vector (signed) semantics
- `Cardinal.swift` — Cardinal (non-negative) semantics

---

## Implementation Record

**Implemented**: 2026-01-29

### Files Changed

1. **`Input.Protocol.swift`** — Changed protocol requirement:
   - `advance(by offset: Index<Element>.Offset)` → `advance(by count: Index<Element>.Count)`
   - Precondition simplified from `offset >= .zero && offset <= count` to `count <= self.count`

2. **`Input.Buffer+Input.Protocol.swift`** — Updated conformance:
   ```swift
   public mutating func advance(by count: Index<Element>.Count) {
       position = storage.index(position, offsetBy: Int(bitPattern: count))
   }
   ```

3. **`Input.Slice+Input.Protocol.swift`** — Updated conformance:
   ```swift
   public mutating func advance(by count: Index<Element>.Count) {
       startIndex = base.index(startIndex, offsetBy: Int(bitPattern: count))
   }
   ```

4. **`Input.Remove.swift`** — Removed conversion ceremony:
   - `advance(by: Index<Base.Element>.Offset(count))` → `advance(by: count)`

### Design Note

The conformance implementations use `Int(bitPattern: count)` to convert the typed `Count` to the stdlib's `Int` parameter. This is preferable to adding `index(_:offsetBy: Count)` overloads to Collection protocols because:
- The conversion is local and explicit
- No API surface added to Collection types
- `Index<T> + Index<T>.Count` arithmetic exists but doesn't apply here since `position` is `Storage.Index`, not `Index<T>`

### Verification

- `swift build` succeeds for swift-input-primitives
