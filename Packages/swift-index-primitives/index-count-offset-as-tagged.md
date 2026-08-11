# Research: Index.Count and Index.Offset as Tagged Types

<!--
---
title: Index.Count and Index.Offset as Tagged Types
status: DECISION
last_updated: 2026-03-16
created: 2026-01-27
package: swift-index-primitives
affects: [swift-index-primitives, swift-range-primitives, swift-pointer-primitives]
tags: [architecture, tagged, phantom-types]
---
-->

## Question

Should `Index<Element>.Count` and `Index<Element>.Offset` be restructured from nested structs to `Tagged` typealiases, enabling the Tagged functor machinery (`retag`, `map`) to work uniformly across all phantom-typed index-related types?

## Context

Currently:
- `Index<E>` = `Tagged<E, Ordinal>` ✓ (IS a Tagged type)
- `Index<E>.Count` = nested struct wrapping `Cardinal`
- `Index<E>.Offset` = nested struct wrapping `Affine.Discrete.Vector`

The nested struct approach requires manual implementations of:
- `Equatable`, `Hashable`, `Comparable` operators
- Cross-domain initializers for retagging
- Arithmetic operators delegating to underlying types

The observation: Tagged already provides `retag()` and `map()` functors, but these don't work with the nested structs because they aren't Tagged types.

## Options

### Option 1: Current Design (Nested Structs)

```swift
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public struct Count: Hashable, Comparable, Sendable {
        public let count: Cardinal
        // Manual conformances, manual cross-domain init, manual arithmetic
    }

    public struct Offset: Hashable, Comparable, Sendable {
        public let vector: Affine.Discrete.Vector
        // Manual conformances, manual cross-domain init, manual arithmetic
    }
}
```

### Option 2: Tagged Typealiases

```swift
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public typealias Count = Tagged<Tag, Cardinal>
    public typealias Offset = Tagged<Tag, Affine.Discrete.Vector>
}
```

Then `Index<Foo>.Count` = `Tagged<Foo, Cardinal>` and all Tagged machinery applies.

### Option 3: Hybrid (Tagged with Extension Methods)

Same as Option 2, but add convenience extensions to maintain current API:

```swift
extension Tagged where RawValue == Cardinal, Tag: ~Copyable {
    @inlinable
    public var count: Cardinal { rawValue }

    @inlinable
    public static var zero: Self { Self(__unchecked: (), .zero) }

    @inlinable
    public static var one: Self { Self(__unchecked: (), .one) }
}
```

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Functor support | High | Does `retag()` and `map()` work? |
| API consistency | High | Do all phantom-typed wrappers use same patterns? |
| Boilerplate reduction | Medium | How much manual code is eliminated? |
| API preservation | Medium | Can existing API surface be maintained? |
| Migration complexity | Medium | How hard is migration for consumers? |
| Type safety | High | Is phantom-type safety preserved? |
| Performance | Low | Is there any runtime difference? |

## Analysis

### Functor Support

| Option | `retag()` | `map()` | Cross-domain init |
|--------|-----------|---------|-------------------|
| 1: Nested Struct | ❌ N/A | ❌ N/A | Manual implementation |
| 2: Tagged Typealias | ✓ Built-in | ✓ Built-in | `other.retag(Tag.self)` |
| 3: Hybrid | ✓ Built-in | ✓ Built-in | `other.retag(Tag.self)` |

### API Consistency

| Option | Index | Index.Count | Index.Offset |
|--------|-------|-------------|--------------|
| 1: Nested Struct | Tagged | struct | struct |
| 2: Tagged Typealias | Tagged | Tagged | Tagged |
| 3: Hybrid | Tagged | Tagged | Tagged |

Option 2/3 provides uniform Tagged semantics across all phantom-typed index types.

### Boilerplate Reduction

**Current (Option 1) requires in Index.Count.swift:**
- Lines 108-116: Manual `==` and `<` operators
- Lines 91-93: Manual cross-domain init
- Index.Count+Arithmetic.swift: Manual `+`, `*`, `+=` operators

**With Option 2/3:**
- `==`, `<` come free from Tagged conditional conformances
- `retag()` replaces cross-domain init
- Arithmetic still needs explicit operators (but delegating to rawValue)

**Estimated reduction**: ~40 lines of boilerplate per type (Count, Offset)

### API Preservation

| Current API | Option 1 | Option 2 | Option 3 |
|-------------|----------|----------|----------|
| `count.count` | ✓ | ❌ → `count.rawValue` | ✓ via `count` computed property |
| `count.rawValue` (UInt) | ✓ | ❌ → `count.rawValue` | ✓ via extension |
| `.zero`, `.one` | ✓ | Needs extension | ✓ via extension |
| `Index.Count(5 as UInt)` | ✓ | Needs extension | ✓ via extension |

**Option 3 can preserve the entire current API** through extensions on `Tagged where RawValue == Cardinal`.

### Migration Complexity

**Source-breaking changes with Option 2 (no extensions):**
- `count.count` → `count.rawValue`
- `count.rawValue` → `count.rawValue`

**With Option 3:**
- No source-breaking changes if extensions provide compatibility API
- Internal implementation changes only

### Type Safety

All options preserve phantom-type safety:
- `Index<Foo>.Count` cannot be compared with `Index<Bar>.Count`
- Cross-domain conversion requires explicit retagging

### Performance

All options compile to identical runtime code:
- Tagged is a zero-cost wrapper
- All operations inline

## Constraints

1. **Backward compatibility**: Existing code using `Index<T>.Count` must continue to compile
2. **Arithmetic semantics**: Count arithmetic must preserve monus (saturating subtraction) behavior
3. **~Copyable support**: All types must support `~Copyable` phantom tags

## Recommendation

**RECOMMENDED: Option 3 (Hybrid)**

Restructure `Index.Count` and `Index.Offset` as Tagged typealiases, with extensions providing the current API surface:

```swift
// Type definitions
extension Tagged where RawValue == Ordinal, Tag: ~Copyable {
    public typealias Count = Tagged<Tag, Cardinal>
    public typealias Offset = Tagged<Tag, Affine.Discrete.Vector>
}

// API compatibility extensions
extension Tagged where RawValue == Cardinal, Tag: ~Copyable {
    @inlinable
    public var count: Cardinal { rawValue }

    @inlinable
    public var rawValue: UInt { rawValue.rawValue }  // Shadows for convenience
    // ... etc
}
```

**Rationale:**
1. Enables `retag()` and `map()` functor operations
2. Provides uniform Tagged semantics across all phantom-typed index types
3. Reduces ~80 lines of boilerplate (40 per type)
4. Preserves backward compatibility through extensions
5. Zero runtime cost

## Implementation Notes

1. Move typealias definitions to Index.Count.swift and Index.Offset.swift
2. Convert struct body to extension on `Tagged where RawValue == Cardinal`
3. Convert cross-domain init to documentation recommending `retag()`
4. Update tests to verify functor operations work
5. Verify all consumers still compile

## Open Questions

1. Should the `count` property be deprecated in favor of `rawValue`?
2. Should arithmetic operators remain on the extensions or be generalized to Tagged?
3. Are there edge cases where nested struct semantics differ from Tagged semantics?

## Outcome

**DECISION** (2026-03-16): Option 3 (Hybrid) chosen — restructure `Index.Count` and `Index.Offset` as Tagged typealiases with extension methods preserving the current API. Prototype validated (12/12 tests pass).

## Status

**VALIDATED** - Prototype implementation confirms Option 3 works.

### Validation Results (2026-01-27)

Prototype file: `Tests/Index Primitives Tests/Index.Count.Tagged.Experiment.swift`

```
12 tests passed:
✓ Construction from UInt
✓ Construction from Int
✓ Construction from negative Int throws
✓ Static constants (.zero, .one)
✓ Equality (free from Tagged)
✓ Comparison (free from Tagged)
✓ Hashable (free from Tagged)
✓ Arithmetic (via extension)
✓ retag() - THE KEY BENEFIT
✓ map() - transform raw value
✓ Cross-domain conversion via retag
✓ Phantom type safety preserved
```

**Key Findings:**
1. `Tagged<Tag, Cardinal>` works as a drop-in replacement
2. All Tagged functor operations (`retag`, `map`) work correctly
3. Equatable, Hashable, Comparable derive automatically
4. Extensions can maintain full API compatibility
5. Zero runtime cost - same compiled code

## Related Documents

- [Tagged.swift](/Users/coen/Developer/swift-primitives/swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift) - retag/map definitions
- [Index.Count.swift](/Users/coen/Developer/swift-primitives/swift-index-primitives/Sources/Index Primitives/Index.Count.swift) - current implementation
- [Index.Offset.swift](/Users/coen/Developer/swift-primitives/swift-index-primitives/Sources/Index Primitives/Index.Offset.swift) - current implementation
