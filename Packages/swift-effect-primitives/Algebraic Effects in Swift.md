# Algebraic Effects in Swift: Design Patterns, Language Limitations, and Practical Implementation
<!--
---
version: 1.0.0
last_updated: 2026-01-18
status: IMPLEMENTED
---
-->

## Abstract

Algebraic effects provide a principled approach to managing computational side effects through a separation of effect declaration from effect interpretation. This paper presents a practical implementation of algebraic effects in Swift, examining the theoretical foundations, design challenges arising from Swift's type system constraints, and novel patterns developed to achieve ergonomic APIs. We introduce the hoisted protocol pattern for namespace-preserving type definitions, analyze generic parameter shadowing in protocol conformance, and document workarounds for Swift's current limitations on noncopyable associated types. Our implementation demonstrates that algebraic effects can be integrated into Swift's existing ecosystem while maintaining type safety and composability.

## 1. Introduction

Algebraic effects, originating from Plotkin and Power's work on computational effects (2003) and later formalized by Plotkin and Pretnar (2009), represent a paradigm for structuring effectful computations. Unlike monadic effect systems that compose effects through nested transformers, algebraic effects enable flat composition through effect handlers that intercept and interpret effect operations.

Swift presents a unique challenge for implementing algebraic effects. As a systems programming language with strong static typing, value semantics, and evolving support for noncopyable types, Swift's type system simultaneously enables sophisticated abstractions while imposing constraints that require creative solutions.

This paper documents the design and implementation of `swift-effect-primitives` and its integration into three domain-specific packages: cache primitives, resource pool primitives, and parsing primitives. Each domain exercises different aspects of the effect system, from simple notification effects to multi-shot continuations enabling backtracking.

## 2. Theoretical Foundation

### 2.1 Effect Operations and Handlers

An algebraic effect consists of a set of *operations* that suspend the current computation and yield control to a *handler*. The handler interprets the operation and resumes the computation via a *continuation*. Formally:

```
Effect ::= { op₁ : A₁ → B₁, ..., opₙ : Aₙ → Bₙ }
```

Each operation `opᵢ` takes an argument of type `Aᵢ` and, when handled, produces a value of type `Bᵢ` to resume with.

In our Swift implementation, this maps to:

```swift
public protocol __EffectProtocol: Sendable {
    associatedtype Arguments: Sendable = Void
    associatedtype Value: Sendable
    associatedtype Failure: Error = Never
    var arguments: Arguments { get }
}
```

The `Arguments` type corresponds to `Aᵢ`, `Value` to `Bᵢ`, and `Failure` captures the possibility of effectful failure—a practical necessity in real systems.

### 2.2 Continuation Semantics

Handlers receive a continuation representing the rest of the computation:

```swift
public protocol __EffectHandler: Sendable {
    associatedtype Handled: __EffectProtocol
    func handle(
        _ effect: Handled,
        continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>
    ) async
}
```

The `consuming` keyword indicates move-only semantics for one-shot continuations, ensuring exactly-once resumption—a critical invariant for resource safety. For effects requiring non-determinism (e.g., backtracking), multi-shot continuations (`Effect.Continuation.Multi`) allow multiple resumptions.

### 2.3 Handler Composition

Unlike monad transformers where effect order is encoded in type nesting (`StateT s (ReaderT r IO)`), algebraic effects compose flatly. Multiple handlers can be installed in a handler stack, with effect operations dynamically dispatched to the nearest matching handler. This is implemented via task-local storage:

```swift
extension Effect {
    public enum Context {
        @TaskLocal public static var current: Dependency.Scope = .empty
    }
}
```

## 3. The Namespace Challenge: Hoisted Protocol Pattern

### 3.1 The Problem

Swift's API design guidelines and the Swift Institute's requirements mandate hierarchical naming via the `Nest.Name` pattern. Types should be organized as `Domain.Concept`, enabling discoverability through autocomplete and communicating relationships through hierarchy.

However, Swift prohibits nesting protocols inside generic types:

```swift
struct Cache<Key, Value> {
    protocol Computable { } // Error: Protocol cannot be nested
}
```

This limitation extends to any construct requiring a named type in a position where generic context would be ambiguous.

### 3.2 The Solution: Hoisting with Typealiases

We employ a two-level pattern:

1. **Hoist** the protocol/struct to module level with a `__` prefix (indicating internal machinery)
2. **Create a typealias** in the intended namespace providing the clean API

```swift
// Module level (hoisted)
public protocol __EffectProtocol: Sendable { ... }

// Namespace (clean API)
public enum Effect {
    public typealias `Protocol` = __EffectProtocol
}
```

Users interact with `Effect.Protocol` while the implementation uses `__EffectProtocol`. The backticks around `Protocol` are required since it's a keyword, but this is invisible at call sites due to Swift's contextual keyword resolution.

### 3.3 Generic Type Extensions

For types nested in generic parents, the pattern requires careful consideration of type parameter binding. Consider:

```swift
public struct Cache<Key: Hashable & Sendable, Value: Sendable>: Sendable { ... }
```

An effect for cache eviction must be parameterized by key and value types. Two approaches exist:

**Approach A: Independent Parameters**
```swift
extension Cache {
    public typealias Evict<K, V> = __CacheEvict<K, V>
}
// Usage: Cache.Evict<String, Int> — Ambiguous with Cache's own parameters
```

**Approach B: Bound Parameters**
```swift
extension Cache {
    public typealias Evict = __CacheEvict<Key, Value>
}
// Usage: Cache<String, Int>.Evict — Clear and ergonomic
```

Approach B binds the effect's type parameters to the enclosing `Cache`'s parameters, yielding natural usage where the effect type derives from a specific cache instantiation.

## 4. Associated Type Shadowing

### 4.1 The Problem

When a generic struct conforms to a protocol with an associated type, naming collisions can occur:

```swift
public struct __CacheEvict<Key, Value>: Effect.`Protocol` {
    // Effect.Protocol requires: associatedtype Value
    // But Value is already a generic parameter!
}
```

Swift resolves this by using the generic parameter to satisfy the associated type requirement. This is problematic when the semantic meanings differ:

- **Generic parameter `Value`**: The type of data stored in the cache
- **Associated type `Value`**: The return type when the effect is handled (should be `Void` for notifications)

### 4.2 The Solution

Rename the generic parameter to avoid collision:

```swift
public struct __CacheEvict<Key: Hashable & Sendable, V: Sendable>: Effect.`Protocol` {
    public typealias Value = Void      // Effect returns nothing
    public let value: V                 // The evicted cache value
}
```

The single-letter `V` follows Swift convention for generic parameters (`T`, `U`, `V`, `E`) and clearly distinguishes from the protocol's `Value` associated type.

## 5. Noncopyable Types and Effect Values

### 5.1 The Motivation

Resource management benefits from noncopyable (`~Copyable`) types that enforce single-ownership semantics. A resource pool should ideally express:

```swift
public struct Acquire<Resource: ~Copyable & Sendable>: Effect.`Protocol` {
    public typealias Value = Resource  // Swift limitation
}
```

This would guarantee that acquired resources cannot be duplicated, enforcing the borrow-use-return pattern at the type level.

### 5.2 Current Swift Limitations

Swift Evolution proposals SE-0390, SE-0427, and SE-0437 introduced noncopyable types, but associated types cannot yet suppress `Copyable`:

```swift
protocol Effect {
    associatedtype Value: ~Copyable  // Error: Cannot suppress Copyable
}
```

The "Suppressed Associated Types With Defaults" pitch proposes syntax like:

```swift
associatedtype Value: ~Copyable = Int  // Proposed, not yet accepted
```

Until this lands, associated types implicitly require `Copyable` conformance.

### 5.3 The Workaround: Reference.Box

We employ a reference wrapper from `swift-reference-primitives`:

```swift
public struct Box<Value: ~Copyable & Sendable>: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<Value>
    // Single-ownership semantics via manual memory management
}
```

The effect uses this wrapper:

```swift
public struct Acquire<Resource: ~Copyable & Sendable>: Effect.`Protocol` {
    public typealias Value = Reference.Box<Resource>
}
```

This preserves the type relationship while satisfying `Copyable` requirements. The `Box` itself is technically copyable (it's a pointer), but its API enforces single-access patterns. This is a pragmatic compromise pending language evolution.

## 6. Domain-Specific Effect Design

### 6.1 Cache Effects

Caches exhibit two natural effect operations:

**Compute Effect**: Requests computation of a missing value.

```swift
public struct __CacheCompute<Key, Value, E: Error>: Effect.`Protocol` {
    public typealias Arguments = Key
    public typealias Value = Value      // Computed result
    public typealias Failure = E
    public let key: Key
}
```

The error type `E` remains a free parameter since different computations may fail differently.

**Evict Effect**: Notifies of entry removal.

```swift
public struct __CacheEvict<Key, V>: Effect.`Protocol` {
    public typealias Arguments = (key: Key, value: V, reason: Reason)
    public typealias Value = Void       // Notification, no return
    public typealias Failure = Never    // Cannot fail
    public enum Reason { case explicit, capacityLimit, expired, replaced, cleared }
}
```

### 6.2 Pool Effects

Resource pools model borrow semantics:

**Acquire Effect**: Requests a resource from the pool.

```swift
public struct Acquire<Resource: ~Copyable & Sendable>: Effect.`Protocol` {
    public typealias Arguments = Pool.Scope
    public typealias Value = Reference.Box<Resource>
    public typealias Failure = Pool.Error
}
```

**Release Effect**: Returns a resource to the pool.

```swift
public struct Release<Resource: ~Copyable & Sendable>: Effect.`Protocol` {
    public typealias Arguments = Pool.ID
    public typealias Value = Void
    public typealias Failure = Never
}
```

### 6.3 Parsing Effects

Parsing requires non-determinism for backtracking:

**Backtrack Effect**: Explores alternatives via multi-shot continuations.

```swift
public struct Backtrack<Input: Parsing.Input, Output, E: Error>: Effect.`Protocol` {
    public typealias Alternative = @Sendable (inout Input) throws(E) -> Output
    public typealias Arguments = [Alternative]
    public typealias Value = Output
    public typealias Failure = E
    public let alternatives: [Alternative]
}
```

Handlers use `Effect.Continuation.Multi` to try each alternative:

```swift
func handle(_ effect: Backtrack<I, O, E>, continuation: Effect.Continuation.Multi<O, E>) async {
    for alternative in effect.alternatives {
        let forked = continuation.fork()
        // Try alternative, resume forked continuation on success
    }
}
```

## 7. Import Visibility and Module Boundaries

### 7.1 The MemberImportVisibility Diagnostic

Swift 6 enforces that types used in `@inlinable` or `@usableFromInline` declarations must be visible to clients. An `internal` import makes a dependency's public types internal to the importing module:

```swift
import Storage_Primitives  // Internal import
@usableFromInline var slab: Slab<T>  // Error: Slab is internal
```

### 7.2 The Solution

Use `public import` to re-export the dependency:

```swift
public import Storage_Primitives  // Re-exports publicly
@usableFromInline var slab: Slab<T>  // Slab is public
```

This must be applied consistently across all files using types from the dependency in inlinable contexts.

## 8. Evaluation

### 8.1 Type Safety

The implementation maintains Swift's type safety guarantees:

- Effect operations are statically typed with known argument, value, and failure types
- Handlers are type-checked against the effects they claim to handle
- One-shot continuations use move-only semantics to prevent double-resumption

### 8.2 Ergonomics

The hoisted pattern with bound typealiases achieves clean syntax:

```swift
let effect = Cache<String, User>.Evict(key: "user-1", value: user, reason: .expired)
let acquire = Pool.Acquire<Connection>(scope: scope)
```

This matches Swift's standard library patterns (e.g., `Dictionary<K, V>.Keys`).

### 8.3 Limitations

1. **Noncopyable associated types**: Requires `Reference.Box` workaround
2. **Runtime dispatch**: Handler lookup via task-locals incurs dynamic overhead
3. **No effect polymorphism**: Cannot abstract over "any effect" without existentials

## 9. Related Work

**Koka** (Leijen, 2014) provides native algebraic effects with row-polymorphic effect types. Our Swift implementation lacks effect rows but achieves similar handler composition.

**OCaml 5** introduced effect handlers as a language feature. Swift's approach is library-based, trading language integration for portability.

**Swift Concurrency** provides structured concurrency but not algebraic effects. Our work complements async/await by adding interceptable effect operations.

## 10. Future Directions

1. **Language evolution**: SE-0499 and successor proposals may enable `~Copyable` associated types
2. **Effect inference**: Macro-based effect tracking could provide static effect checking
3. **Performance**: Specialized handler dispatch via generic specialization

## 11. Conclusion

Algebraic effects can be practically implemented in Swift through careful navigation of type system constraints. The hoisted protocol pattern preserves namespace hierarchies despite nesting limitations. Generic parameter naming must account for associated type shadowing. Noncopyable resources require temporary workarounds pending language evolution.

Our implementation in `swift-effect-primitives` and its domain-specific applications demonstrates that algebraic effects provide value in Swift for testable side effects, resource management, and non-deterministic computation, while maintaining the language's commitment to type safety and zero-cost abstractions where possible.

## References

- Leijen, D. (2014). Koka: Programming with Row Polymorphic Effect Types.
- Plotkin, G., & Power, J. (2003). Algebraic Operations and Generic Effects.
- Plotkin, G., & Pretnar, M. (2009). Handlers of Algebraic Effects.
- Swift Evolution SE-0390: Noncopyable Types.
- Swift Evolution SE-0427: Noncopyable Generics.
- Swift Evolution SE-0437: Noncopyable Standard Library Primitives.
- Swift Institute API Requirements, v2.2.0.
