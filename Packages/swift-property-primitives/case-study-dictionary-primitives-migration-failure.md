# Case Study: Why Property<Tag, Base> Cannot Replace Concrete Proxy Types in Dictionary Primitives
<!--
---
version: 1.0.0
last_updated: 2026-01-21
status: DECISION
---
-->

**Coen ten Thije Boonkkamp**
Swift Institute
January 2026

---

## Abstract

This paper documents an attempted migration of `swift-dictionary-primitives` accessor types to the unified `Property<Tag, Base>` abstraction. Despite successful migrations in `swift-deque-primitives` and `swift-heap-primitives`, dictionary primitives presents two distinct and insurmountable obstacles: protocol conformance requirements on `Values` and doubly-nested generic accessor chains on `Merge`/`Keep`. We characterize each obstacle, reference the experimental evidence, and conclude that concrete proxy structs remain the correct design for this package.

---

## 1. Introduction

The `Property<Tag, Base>` type family was designed to unify fluent API accessor patterns across the swift-primitives ecosystem. Previous migrations achieved significant reductions in boilerplate:

| Package | Proxy Structs Before | After Migration |
|---------|---------------------|-----------------|
| swift-deque-primitives | 4 | 0 (1 typealias) |
| swift-heap-primitives | 4 | 0 (1 typealias) |

The natural expectation was that `swift-dictionary-primitives` would follow the same pattern, reducing its 3 proxy structs (`Values`, `Merge`, `Keep`) to phantom tags with a shared typealias. This expectation proved incorrect.

---

## 2. Dictionary Primitives Accessor Structure

`Dictionary.Ordered` exposes three accessor types:

```swift
dict.values.set("key", value)     // Values accessor
dict.values.remove("key")
for v in dict.values { ... }      // Sequence iteration

dict.merge.keep.first(pairs)      // Nested Merge → Keep accessor
dict.merge.keep.last(pairs)
```

Two distinct patterns emerge:

1. **Values**: Single-level accessor requiring `Sequence` conformance
2. **Merge/Keep**: Doubly-nested accessor chain (`merge.keep.method()`)

Each pattern encounters a different fundamental limitation.

---

## 3. Obstacle 1: Protocol Conformance on Values

### 3.1 The Requirement

`Values` must conform to `Sequence` to support idiomatic iteration:

```swift
for value in dict.values {
    process(value)
}
```

### 3.2 The Limitation

As documented in "Protocol Conformance and Phantom Type Generalization" (Swift Institute, 2026), Swift's protocol conformance system has three critical constraints:

1. **Single Conformance Rule**: A type can conform to a protocol only once
2. **No Generic Parameters in Conformance Constraints**: Cannot write `extension<K, V> Property.Typed: Swift.Sequence where ...`
3. **Concrete Types Only**: Constrained conformances work only for specific concrete instantiations

For `Property.Typed` to support `Sequence` for dictionary values, we would need:

```swift
// INVALID SWIFT - cannot introduce K, V
extension<K: Hashable, V: Copyable> Property.Typed: Sequence
where Tag == Dictionary<K, V>.Ordered.Values,
      Base == Dictionary<K, V>.Ordered,
      Element == V {
    // ...
}
```

Swift provides no syntax for this. We can only write:

```swift
// Valid but useless - only works for Dictionary<String, Int>
extension Property.Typed: Sequence
where Tag == Dictionary<String, Int>.Ordered.Values,
      Base == Dictionary<String, Int>.Ordered,
      Element == Int {
    // ...
}
```

A primitives library must work for all `Dictionary<K, V>`, not just specific concrete instantiations.

### 3.3 Experimental Confirmation

The `property-phantom-conformance-test` experiment confirmed:

```
Finding 1: Concrete constrained conformance - WORKS
Finding 2: Generic constrained conformance - IMPOSSIBLE
Finding 3: Multiple conformances - FORBIDDEN
Finding 4: Unconditional conformance - CAUSES POLLUTION
```

**Conclusion**: `Values` must remain a concrete struct to support `Sequence` conformance.

---

## 4. Obstacle 2: Doubly-Nested Generic Accessor Chain

### 4.1 The Requirement

The merge API uses a doubly-nested accessor pattern:

```swift
dict.merge.keep.first(pairs)
//   ^^^^^ ^^^^ ^^^^^
//   L1    L2   method
```

Both levels must work for all `Dictionary<K, V>`.

### 4.2 Property.Typed and the Single-Parameter Limitation

`Property<Tag, Base>.Typed<Element>` exists precisely to enable property extensions by "smuggling" a type parameter into scope. For single-parameter generics like `Deque<Element>`, this works perfectly:

```swift
// Element is in scope via Typed<Element>
extension Property.Typed
where Tag == Deque<Element>.Peek, Base == Deque<Element> {
    var back: Element? { base.last }  // ✓ Works
}
```

However, `Dictionary<Key, Value>` has **two** generic parameters, and `Typed<Element>` only smuggles **one**:

```swift
// Element = Value, but Key is NOT in scope
extension Property.Typed
where Tag == Dictionary<???, Element>.Ordered.Keep,  // ← Missing Key
      Base == Dictionary<???, Element>.Ordered {
    // Cannot write constraint - Key unavailable
}
```

### 4.2.1 Multi-Parameter Solutions Investigated

The `property-typed-parameter-pack-test` experiment investigated several approaches:

| Approach | Viability | Issue |
|----------|-----------|-------|
| Parameter packs (`Typed<each T>`) | Compiles | Cannot project pack elements in where clauses |
| Nested Typed (`Typed<A>.Typed<B>`) | Works | Requires multiple struct definitions per level |
| Protocol Witness (types in Tag) | Works | Requires marker protocols on all tags |
| Tuple parameters (`Typed<(A,B)>`) | Fails | Cannot destructure tuple types in where clauses |

**Conclusion**: All solutions add complexity without sufficient benefit over concrete structs.

### 4.3 The Doubly-Nested Constraint

The `property-doubly-nested-accessor-test` experiment confirmed that doubly-nested accessors work with Property for **concrete types**:

```swift
extension Property where Tag == Container<Int>.Stack, Base == Container<Int> {
    var push: Property<Container<Int>.Stack.Push, Container<Int>> {
        // Works - no generics needed, types are concrete
    }
}
```

For **generic types** like `Dictionary<K, V>`, the second-level accessor would need to introduce both `K` and `V`:

```swift
extension Property {
    // PROBLEM: .keep is a property, cannot introduce K, V
    var keep: Property<Dictionary<K, V>.Ordered.Keep, Dictionary<K, V>.Ordered>
    where Tag == Dictionary<K, V>.Ordered.Merge, ... {
        // K and V are not in scope
    }
}
```

Methods can introduce generics, but this changes the API:

```swift
extension Property {
    // This works but changes the API
    func keep<K: Hashable, V: Copyable>() -> Property<...>
    where Tag == Dictionary<K, V>.Ordered.Merge, ... {
        // K and V introduced by method
    }
}
```

This would change the API from `dict.merge.keep.first()` to `dict.merge.keep().first()`, breaking the fluent pattern.

### 4.3 The Generic Scope Problem

Even if we accepted the method-based API, there's a deeper issue. When extending `Property_Primitives.Property`, we lose access to `Key` and `Value`:

```swift
// Inside Dictionary.Ordered extension - Key and Value are in scope
extension Dictionary_Primitives.Dictionary.Ordered.Merge.Keep {
    mutating func first(_ pairs: some Swift.Sequence<(Key, Value)>) {
        // Key and Value available from enclosing type
    }
}

// Outside, extending Property - must introduce new generics
extension Property_Primitives.Property {
    mutating func first<K: Hashable, V: Copyable>(_ pairs: some Swift.Sequence<(K, V)>)
    where Tag == Dictionary<K, V>.Ordered.Keep, Base == Dictionary<K, V>.Ordered {
        // Must use K, V instead of reusing Key, Value
    }
}
```

This is not just verbose—it creates a semantic gap. The concrete struct approach keeps `Key` and `Value` in scope naturally.

**Conclusion**: `Merge` and `Keep` must remain concrete structs to preserve the property-based accessor chain for generic dictionary types.

---

## 5. Why Deque and Heap Succeeded

Deque and Heap have simpler structures:

```swift
deque.push.back(element)   // Single-level, method only
deque.peek.back            // Single-level, property only
```

Key differences:

| Aspect | Deque/Heap | Dictionary |
|--------|-----------|------------|
| Nesting depth | 1 level | 2 levels (merge.keep) |
| Protocol conformance | None | Sequence on Values |
| Generic parameters | 1 (Element) | 2 (Key, Value) |

The single generic parameter is crucial: `Property.Typed<Element>` perfectly smuggles `Element` into scope for property extensions like `peek.back`. With two parameters (`Key`, `Value`), one is always missing.

With single nesting, one generic parameter, and no protocol conformance, the Property pattern works elegantly. Dictionary's requirements exceed what the pattern can express.

---

## 6. Decision Matrix

| Accessor | Blocker | Resolution |
|----------|---------|------------|
| Values | Requires Sequence for all `Dictionary<K, V>` | Keep concrete struct |
| Merge | Property accessor cannot introduce K, V for generic `.keep` | Keep concrete struct |
| Keep | Would lose access to Key, Value in scope | Keep concrete struct |

**Final Decision**: Do not migrate `swift-dictionary-primitives` to Property pattern.

---

## 7. Documentation Added

The following comment was added to `Dictionary.Ordered.Merge.swift`:

```swift
// NOTE: Merge and Keep remain as concrete structs rather than using Property<Tag, Base>
// because the nested accessor pattern (dict.merge.keep.first()) requires:
// 1. `.keep` to be a property (not a method)
// 2. Properties cannot introduce generic parameters
// 3. If we extended Property_Primitives.Property, we'd lose access to Key/Value
// See: "Protocol Conformance and Phantom Type Generalization" paper.
```

---

## 8. Implications for Future Migrations

The Property pattern is suitable when:

1. Accessors are single-level (not nested), OR doubly-nested with concrete types
2. No protocol conformance is required, OR conformance can be universal
3. The base type has **exactly one** generic parameter (so `Typed<Element>` can smuggle it)

The Property pattern is NOT suitable when:

1. Accessors are doubly-nested with **generic** property chains
2. Protocol conformance is required for generic type families
3. The base type has **two or more** generic parameters (`Typed<Element>` only provides one)

---

## 9. Conclusion

The `Property<Tag, Base>` abstraction successfully unified accessor patterns in Deque and Heap, but dictionary primitives presents requirements that exceed the pattern's expressiveness. Two independent obstacles—protocol conformance limitations and doubly-nested generic accessor chains—each independently prevent migration. The concrete proxy struct design, while requiring more boilerplate, correctly handles both requirements.

This case study demonstrates that unified abstractions have boundaries. Recognizing these boundaries and documenting them clearly is as valuable as the abstractions themselves.

---

## References

1. ten Thije Boonkkamp, C. "Property Type Family: A Unified Abstraction for Fluent API Accessors in Swift." Swift Institute, 2026.
2. ten Thije Boonkkamp, C. "Protocol Conformance and Phantom Type Generalization: A Fundamental Tension in Swift's Type System." Swift Institute, 2026.
3. Swift Institute. "property-phantom-conformance-test experiment." swift-property-primitives, 2026.
4. Swift Institute. "property-doubly-nested-accessor-test experiment." swift-property-primitives, 2026.
5. Swift Institute. "property-typed-parameter-pack-test experiment." swift-property-primitives, 2026.

---

## Appendix: Experimental Evidence

### A. Phantom Conformance Test Results

```
Finding 1: Concrete constrained conformance - CONFIRMED WORKS
Finding 2: Generic constrained conformance - CONFIRMED IMPOSSIBLE
Finding 3: Multiple conformances - CONFIRMED FORBIDDEN
Finding 4: Unconditional conformance - CONFIRMED CAUSES POLLUTION
```

### B. Doubly Nested Accessor Test Results

```
Variant 1: instance.first.second.property     - CONFIRMED (concrete types only)
Variant 2: instance.first.second.method()     - CONFIRMED (concrete types only)
Variant 3: instance.first.second.method(x)    - CONFIRMED (concrete types only)
Variant 4: Queue doubly nested pattern        - CONFIRMED (concrete types only)
Variant 5: Generic doubly nested chain        - CONFIRMED (requires method, not property)
```

### C. Multi-Parameter Solutions Test Results

```
Parameter packs (Typed<each T>)     - COMPILES but cannot project elements in where clauses
Nested Typed (Typed<A>.Typed<B>)    - WORKS but requires multiple struct definitions
Protocol Witness pattern            - WORKS but requires marker protocols on all tags
Tuple parameters (Typed<(A,B)>)     - FAILS - cannot destructure in where clauses
```

### D. Files Unchanged

```
Dictionary.Ordered.Values.swift      - Kept as concrete struct (Sequence)
Dictionary.Ordered.Merge.swift       - Kept as concrete struct (nested accessor)
Dictionary.Ordered.Merge.Keep.swift  - Kept as concrete struct (nested accessor)
```
