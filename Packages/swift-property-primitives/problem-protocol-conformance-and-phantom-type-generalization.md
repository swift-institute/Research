# Protocol Conformance and Phantom Type Generalization: A Fundamental Tension in Swift's Type System
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

This paper documents a fundamental tension between Swift's protocol conformance system and phantom-type-based abstractions. When migrating concrete proxy types to a unified `Property<Tag, Base>` abstraction, protocol conformances that were scoped to specific proxy types become inadvertently generalized across all instantiations of the phantom type. This paper characterizes the problem through a concrete example and identifies the underlying type-theoretic limitation.

---

## 1. The Problem

Consider a concrete proxy type that provides namespaced access to dictionary values:

```swift
extension Dictionary.Ordered where Value: Copyable {
    public struct Values {
        var dict: Dictionary<Key, Value>.Ordered
    }
}

extension Dictionary.Ordered.ValueS: Swift.Sequence {
    // Iterator implementation...
}
```

This design correctly scopes `Sequence` conformance to the `Values` type. Users can write:

```swift
for value in dict.values { ... }
```

When migrating to the `Property<Tag, Base>` pattern, `Values` becomes a phantom tag:

```swift
extension Dictionary.Ordered where Value: Copyable {
    public enum Values {}  // Phantom tag

    public var values: Property<Values>.Typed<Value> { ... }
}
```

The problem emerges when attempting to preserve `Sequence` conformance.

---

## 2. The Conformance Generalization Problem

Swift's conformance system operates on types, not on constrained instantiations of generic types. When we write:

```swift
extension Property.Typed: Swift.Sequence where Base: Copyable {
    // ...
}
```

This conformance applies to **all** `Property.Typed` instances where `Base` is `Copyable`—not just those where `Tag == Dictionary.Ordered.Values`.

Swift does not support conformances of the form:

```swift
// NOT VALID SWIFT
extension Property.Typed: Sequence
where Tag == Dictionary<K, V>.Ordered.Values,
      Base == Dictionary<K, V>.Ordered {
    // ...
}
```

The language provides no mechanism to add protocol conformance to a specific phantom-type instantiation while excluding others.

---

## 3. Consequences

### 3.1 Semantic Pollution

If we add `Sequence` conformance to `Property.Typed` to support `Dictionary.Ordered.Values`, then `Deque.Property<Peek>.Typed<Element>` also becomes a `Sequence`—despite `peek` having no meaningful iteration semantics.

```swift
// Unintended: Deque.peek is now iterable
for element in deque.peek { ... }  // Compiles, but semantically meaningless
```

### 3.2 Ambiguous Iterator Requirements

The `Sequence` protocol requires an associated `Iterator` type. For `Property.Typed` to conform, it must provide a single iterator implementation that works for all instantiations. This is impossible when different phantom tags represent fundamentally different abstractions:

- `Dictionary.Ordered.Values` iterates over values
- `Deque.Peek` has no meaningful iteration
- Future tags may iterate over entirely different element types

### 3.3 Breaking the Phantom Type Invariant

Phantom types derive their utility from compile-time discrimination: `Property<A, Base>` and `Property<B, Base>` are distinct types with distinct capabilities. Protocol conformance violates this invariant by treating all instantiations uniformly.

---

## 4. Type-Theoretic Characterization

The issue can be characterized as a mismatch between:

1. **Extension constraints**: Swift allows constraining extensions on type parameters (`where Tag == X`)
2. **Conformance constraints**: Swift does not allow constraining conformances on type parameters

Extensions add members; conformances add protocol witness tables. The latter requires a single, unambiguous implementation strategy, which conflicts with the per-instantiation semantics that phantom types enable.

In type-theoretic terms: Swift's protocol conformance is **parametric** over generic types but does not support **ad-hoc polymorphism** at the conformance level based on phantom type instantiation.

---

## 5. Scope of Impact

This limitation affects any phantom-type abstraction where:

1. Concrete predecessor types had protocol conformances
2. Those conformances were semantically specific to the concrete type
3. The unified abstraction serves multiple distinct use cases

The `Property<Tag, Base>` pattern is particularly susceptible because it unifies diverse accessor patterns—some iterable, some not—under a single generic type.

---

## 6. Conclusion

Swift's protocol conformance system operates at the generic type level, not at the level of phantom-type instantiations. This creates a fundamental tension when migrating concrete types with protocol conformances to phantom-type-based abstractions. The conformance that was correctly scoped to a specific concrete type becomes incorrectly generalized across all phantom instantiations, polluting the type semantics of unrelated use cases.

This is not a bug but a limitation of Swift's current type system design. The language lacks a mechanism to express "this conformance applies only when the phantom type parameter equals this specific type."

---

## References

1. Apple Inc. "Generics." *The Swift Programming Language*, 2024.
2. Wadler, P., and Blott, S. "How to make ad-hoc polymorphism less ad hoc." *POPL*, 1989.
3. ten Thije Boonkkamp, C. "Property Type Family: A Unified Abstraction for Fluent API Accessors in Swift." Swift Institute, 2026.
