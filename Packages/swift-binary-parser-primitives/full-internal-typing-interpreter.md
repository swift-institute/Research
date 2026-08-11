# Full Internal Typing for Interpreter

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

The `Binary.Bytes.withBorrowed` interpreter currently uses `Int` internally for:
1. Comparisons: `remainingInt < 1`, `remainingInt < n`, `consumedInt >= totalInt`
2. Iteration: `for i in 0..<n`, `for _ in 0..<8`
3. Subscript access: `view[offset: i]` where `i` is Int

The directive is: **eliminate all Int conversions and maintain full typed indices throughout**.

Dependencies available:
- `range-primitives`: Provides `Range.Lazy` for typed iteration
- `index-primitives`: Provides `Index<T>`, `Index<T>.Count`, `Index<T>.Offset`
- `array-primitives`: Provides `Array.Dynamic.Indexed<Tag>` for typed subscript access

## Question

How should the interpreter achieve full internal typing using array-primitives and range-primitives, eliminating all Int conversions?

## Analysis

### Available Primitives

#### Typed Comparisons (from `swift-ordinal-primitives/Tagged+Ordinal.swift`)

| Expression | Types | Available |
|------------|-------|-----------|
| `index < count` | `Index<T> < Index<T>.Count` | Yes (disfavored overload) |
| `count < count` | `Index<T>.Count < Index<T>.Count` | Yes (via Cardinal Comparable) |
| `count == .zero` | `Index<T>.Count == Index<T>.Count` | Yes |
| `count == .one` | `Index<T>.Count == Index<T>.Count` | Yes |

#### Typed Iteration (from `swift-range-primitives/Index.Count+Range.Lazy.swift`)

```swift
// Creates Range.Lazy<Index<Tag>> from Index<Tag> and Index<Tag>.Count
(.zero..<count).forEach { index in
    // index is Index<Element>
}
```

#### Typed Arithmetic (from `swift-ordinal-primitives/Tagged+Ordinal.swift`)

| Expression | Types | Available |
|------------|-------|-----------|
| `index + count` | `Index<T> + Index<T>.Count → Index<T>` | Yes |
| `index += .one` | `Index<T> += Index<T>.Count` | Yes |
| `count.subtract.saturating(other)` | `Index<T>.Count → Index<T>.Count` | Yes |

#### Constants

| Constant | Type | Available |
|----------|------|-----------|
| `.zero` | `Index<T>` | Yes |
| `.zero` | `Index<T>.Count` | Yes |
| `.one` | `Index<T>.Count` | Yes |

### Option A: Typed Count Comparisons + Range.Lazy Iteration

**Approach**: Replace all `remainingInt < n` with typed count comparisons, and all `for i in 0..<n` with `Range.Lazy.forEach`.

**Pattern for comparisons**:
```swift
// OLD
let remainingInt = Int(bitPattern: remaining.rawValue)
if remainingInt < 1 { ... }

// NEW
if remaining < .one { ... }
```

```swift
// OLD
if remainingInt < n { ... }

// NEW
let need = Index<UInt8>.Count(Cardinal(UInt(n)))
if remaining < need { ... }
```

**Pattern for iteration**:
```swift
// OLD
for _ in 0..<8 { ... }

// NEW
let eight = Index<UInt8>.Count(Cardinal(8))
(.zero..<eight).forEach { _ in ... }
```

**Subscript access**: The current `view[offset: Int]` requires Int. Options:
1. Add typed subscript `view[index: Index<UInt8>]` to Input.View
2. Peek via iteration index calculation
3. Use `.zero` offset when only peeking at current position

**Advantages**:
- Fully typed throughout
- No Int conversions at runtime
- Type safety prevents mixing byte counts with other domains

**Disadvantages**:
- `Range.Lazy.forEach` is closure-based (may impact optimizer)
- Need to add/modify Input.View subscript

### Option B: Array.Dynamic.Indexed for Storage

**Approach**: Wrap intermediate byte storage in `Array.Dynamic.Indexed<UInt8>` for typed subscript access.

**Usage**:
```swift
var bytes: Array<UInt8>.Dynamic.Indexed<UInt8> = ...
(.zero..<count).forEach { index in
    bytes[index] = view.removeFirst()
}
```

**Advantages**:
- Consistent with array-primitives patterns
- Typed subscript access

**Disadvantages**:
- Only helps with *output* byte arrays, not Input.View peeking
- Additional wrapper type

### Option C: Hybrid - Typed Counts + Inline Iteration

**Approach**: Use typed count comparisons but keep `for _ in 0..<n` for fixed small iterations (2, 4, 8 bytes).

**Rationale**: Small fixed iterations like `for _ in 0..<8` are compile-time known and don't need typed indices. The key is typed *counts* for bounds checking.

**Advantages**:
- Pragmatic balance
- Minimal code changes for fixed iterations
- Full typing where it matters (bounds checking, dynamic counts)

**Disadvantages**:
- Not "fully typed" - still has Int in some places
- Less consistent

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Full typing | Yes | Partial | Partial |
| Code complexity | Medium | High | Low |
| Performance impact | Minimal | Minimal | None |
| Consistency | High | Medium | Low |
| Input.View changes | Yes | No | Yes |
| Aligns with directive | **Yes** | No | No |

## Constraints

1. **Lifetime checker constraints**: The interpreter cannot read computed properties on `Input.View` inside the loop. Position tracking must be external.

2. **Input.View subscript**: Currently `view[offset: Int]`. Needs typed variant.

3. **Range.Lazy.forEach is consuming**: Cannot break out of forEach early. For peek-then-decide patterns, use manual iteration with `Range.Lazy.Iterator`.

## Outcome

**Status**: DECISION

**Chosen approach**: Option A (Typed Count Comparisons + Range.Lazy Iteration)

### Implementation Path

1. **Add range-primitives dependency** to Package.swift

2. **Define typed count constants** at interpreter scope:
   ```swift
   let two = Index<UInt8>.Count(Cardinal(2))
   let four = Index<UInt8>.Count(Cardinal(4))
   let eight = Index<UInt8>.Count(Cardinal(8))
   ```

3. **Replace comparisons**:
   ```swift
   // Before
   if remainingInt < 1 { ... }

   // After
   if remaining < .one { ... }
   ```

4. **Replace fixed iterations** with Range.Lazy:
   ```swift
   // Before
   for i in 0..<8 { result |= UInt64(view.removeFirst()) << (i * 8) }

   // After
   var shift: UInt64 = 0
   (.zero..<eight).forEach { _ in
       result |= UInt64(view.removeFirst()) << shift
       shift += 8
   }
   ```

5. **For subscript peeking**, current `view[offset: 0]` becomes `view[offset: .zero]` if Input.View adds typed subscript, or use:
   ```swift
   // Peek at offset 0 (current position)
   let byte = view[offset: .zero]  // Requires typed subscript addition
   ```

6. **Remove all `remainingInt`, `consumedInt`, `totalInt`** local variables.

### Input.View Typed Subscript

The Input.View needs a typed subscript. This should be added to swift-binary-parser-primitives (not input-primitives, since it's UInt8-specific):

```swift
extension Binary.Bytes.Input.View {
    @inlinable
    subscript(offset index: Index<UInt8>) -> UInt8 {
        self[offset: Int(bitPattern: index)]
    }
}
```

This encapsulates the single Int conversion at the API boundary, keeping the interpreter fully typed.

### Files to Modify

| File | Changes |
|------|---------|
| `Package.swift` | Add range-primitives dependency |
| `Binary.Bytes.withBorrowed.swift` | Replace all Int iterations and comparisons |
| New: `Binary.Bytes.Input.View+typed.swift` | Add typed subscript extension |

## References

- `swift-range-primitives/Index.Count+Range.Lazy.swift` - Typed iteration pattern
- `swift-ordinal-primitives/Tagged+Ordinal.swift` - Index < Count comparisons
- `swift-cardinal-primitives/Tagged+Cardinal.swift` - Count constants and arithmetic
