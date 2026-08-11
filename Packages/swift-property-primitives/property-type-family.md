# Property Type Family: A Unified Abstraction for Fluent API Accessors in Swift
<!--
---
version: 1.0.0
last_updated: 2026-01-21
status: IMPLEMENTED
---
-->

**Coen ten Thije Boonkkamp**
Swift Institute
January 2026

---

## Abstract

Modern Swift APIs increasingly employ fluent accessor patterns to provide ergonomic, namespaced operations on collection types. However, the implementation of these patterns requires substantial boilerplate and exhibits significant duplication across codebases. This paper presents `Property<Tag, Base>`, a unified type family that consolidates fluent API accessor patterns while preserving Swift's copy-on-write semantics and supporting both `Copyable` and `~Copyable` types. We identify three distinct accessor patterns in production Swift code, analyze their semantic requirements, and demonstrate how a phantom-type-based abstraction reduces implementation complexity. Our investigation also documents a fundamental incompatibility between Swift's protocol witness system and `~Copyable` types when using coroutine accessors, leading to a design decision favoring concrete type extensions over protocol-based extensibility.

---

## 1. Introduction

Swift's value semantics and copy-on-write (CoW) optimization strategy present unique challenges for API designers seeking to provide fluent, chainable interfaces. Consider a double-ended queue implementation where users expect operations like:

```swift
deque.push.back(element)
deque.peek.front
deque.take.back
```

Each accessor (`push`, `peek`, `take`) represents a distinct operational namespace, yet the underlying implementation pattern is remarkably consistent across data structures. Despite this consistency, production codebases typically implement each accessor as a bespoke type, resulting in substantial duplication.

This paper presents the design and implementation of `Property<Tag, Base>`, a type family that unifies these patterns. We make the following contributions:

1. A taxonomy of fluent accessor patterns in Swift, identifying three distinct categories based on ownership and lifetime semantics
2. A unified type family (`Property`, `Property.Typed`, `Property.View`) addressing the complete design space
3. Documentation of a Swift compiler limitation regarding protocol conformance with `~Copyable` types
4. A recommended typealias pattern that balances ergonomics with type safety

---

## 2. Background

### 2.1 Copy-on-Write in Swift

Swift's standard library collections employ copy-on-write optimization: multiple references to the same storage share a single buffer until mutation occurs. The `isKnownUniquelyReferenced` function enables types to detect when copying is necessary.

For fluent APIs, this creates a critical constraint: **uniqueness checks must occur before transferring ownership to a proxy type**. Failure to enforce this ordering results in unnecessary copies or, worse, mutation of shared state.

### 2.2 Coroutine Accessors

Swift provides `_read` and `_modify` coroutine accessors that yield borrowed or mutable access to values without copying. These accessors are essential for efficient fluent APIs:

```swift
var push: Property<Push> {
    _modify {
        yield &property
    }
}
```

The `_modify` accessor enables in-place mutation through the proxy type, avoiding the copy that a traditional getter/setter pair would require.

### 2.3 Phantom Types

Phantom types are type parameters that appear in a type's signature but not in its runtime representation. They enable compile-time discrimination between otherwise identical types:

```swift
struct Property<Tag, Base> {
    var base: Base  // Tag has no runtime presence
}
```

Extensions can then be constrained on the phantom type:

```swift
extension Property where Tag == Container.Push {
    mutating func back(_ element: Base.Element) { ... }
}
```

---

## 3. Pattern Taxonomy

We surveyed 18 fluent API implementations across the swift-primitives ecosystem and identified three distinct patterns:

### 3.1 Pattern A: Owned Proxy (10 instances)

The most common pattern transfers ownership to a proxy type, performs operations, then transfers ownership back:

```swift
_modify {
    makeUnique()
    var proxy = Proxy(base: self)
    self = Base()
    defer { self = proxy.base }
    yield &proxy
}
```

**Instances:** `Deque.Push`, `Deque.Pop`, `Deque.Take`, `Deque.Peek`, `Heap.Push`, `Heap.Pop`, `Heap.Peek`, `Heap.Take`, `Dictionary.Ordered.Values`, `Dictionary.Ordered.Merge`

**Characteristics:**
- Owned storage (`var base: Base`)
- CoW-compatible via pre-transfer uniqueness check
- `_modify` accessor with ownership transfer dance

### 3.2 Pattern B: Borrowed View (3 instances)

For `~Copyable` types where ownership transfer is impossible, a pointer-based view provides borrowed access:

```swift
mutating _read {
    yield Property.View(&self)
}
```

**Instances:** `Input.Access`, `Input.Remove`, `Input.Restore`

**Characteristics:**
- Pointer storage (`UnsafeMutablePointer<Base>`)
- `~Copyable, ~Escapable` to prevent escape
- `_read` accessor yielding borrowed view

### 3.3 Pattern C: Domain-Specific (5 instances)

Some patterns have semantics that resist generalization:

| Instance | Semantics |
|----------|-----------|
| `Numeric.Math.Accessor<T>` | Zero-sized token for type dispatch |
| `Binary.Parse.Access<P>` | Namespace wrapper |
| `Terminal.Mode.Access` | Namespace wrapper |
| `Async.Channel.Bounded.Take` | Consuming (ownership transfer) |
| `Parser.Peek<Upstream>` | Composition wrapper |

These patterns remain as concrete types due to their specialized requirements.

---

## 4. The Property Type Family

### 4.1 Design

We introduce a three-member type family:

| Type | Purpose | Storage |
|------|---------|---------|
| `Property<Tag, Base>` | Method extensions | `var base: Base` |
| `Property<Tag, Base>.Typed<Element>` | Property extensions | `var base: Base` |
| `Property<Tag, Base>.View` | Borrowed access | `UnsafeMutablePointer<Base>` |

The distinction between `Property` and `Property.Typed` addresses a fundamental asymmetry in Swift's type system:

- **Methods** can introduce generic parameters: `func back<E>(...) where Tag == Container<E>.Push`
- **Properties** cannot: `var back: ??? where Tag == Container<???>.Peek`

`Property.Typed<Element>` "smuggles" the element type into scope, enabling property extensions:

```swift
extension Property.Typed
where Tag == Container<Element>.Peek, Base == Container<Element> {
    var back: Element? { base.last }
}
```

### 4.2 Parameter Ordering

We adopt the convention `Property<Tag, Base>` following the precedent of `Tagged<Tag, RawValue>`: discriminator first, value second. This ordering emphasizes the phantom type's role as the primary discriminant in extension constraints.

### 4.3 Typealias Pattern

To reduce verbosity at use sites, we recommend a single typealias per container:

```swift
extension Container where Element: Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Container<Element>>
}
```

Accessors then use concise signatures:

```swift
var push: Property<Push> { ... }                    // Methods
var peek: Property<Peek>.Typed<Element> { ... }     // Properties
```

This pattern provides a single point of definition while making the distinction between method and property accessors explicit at the declaration site.

---

## 5. Protocol Extension Investigation

### 5.1 Motivation

Protocol-based extensions offer a theoretical advantage: if Swift eventually supports generic computed properties, extensions on protocols would continue to work unchanged, while extensions on concrete types would require migration.

We investigated defining protocols as extension targets:

```swift
protocol PropertyProtocol {
    associatedtype Namespace
    associatedtype Root
    var base: Root { get set }
}

protocol PropertyTypedProtocol: PropertyProtocol {
    associatedtype Element
}
```

### 5.2 Name Collision Challenge

An initial attempt using `Tag` and `Base` as associated type names:

```swift
extension Property: PropertyProtocol where Base: Copyable {
    typealias Tag = Tag    // Error: shadows generic parameter
    typealias Base = Base  // Error: shadows generic parameter
}
```

This fails because associated type witnesses cannot share names with generic parameters without creating ambiguity.

**Solution:** Use distinct names (`Namespace`, `Root`) for associated types:

```swift
extension Property: PropertyProtocol where Base: Copyable {
    typealias Namespace = Tag
    typealias Root = Base
}
```

### 5.3 Coroutine Accessor Incompatibility

With the naming issue resolved, a more fundamental problem emerged. Given:

```swift
struct Property<Tag, Base: ~Copyable>: ~Copyable {
    var base: Base {
        _read { yield _base }
        _modify { yield &_base }
    }
}

extension Property: PropertyProtocol where Base: Copyable {
    typealias Namespace = Tag
    typealias Root = Base
}
```

The compiler emits:

```
error: 'self.base' is borrowed and cannot be consumed
```

**Analysis:** The protocol requirement `var base: Root { get set }` expects witness by a simple getter/setter pair. When `Property` uses `_read`/`_modify` coroutine accessors on a conditionally-`Copyable` type, the compiler's ownership checker cannot verify that the coroutine accessors satisfy the protocol requirement.

This occurs even though:
1. The conformance is conditional on `Base: Copyable`
2. `_read`/`_modify` can witness `{ get set }` for fully-`Copyable` types

The issue appears to be that the compiler evaluates the witness in the context of the generic type (`Property<Tag, Base: ~Copyable>`) rather than the constrained conformance.

### 5.4 Design Decision

Given the incompatibility, we faced a choice:

| Option | Trade-off |
|--------|-----------|
| Protocol conformance | Lose `~Copyable` support |
| Concrete type extensions | Lose theoretical future-proofing |

We chose concrete type extensions because:

1. `~Copyable` support provides immediate, tangible value
2. The "future-proofing" benefit is speculative
3. Migration from concrete to protocol extensions, if ever needed, is mechanical

---

## 6. Implementation

### 6.1 CoW Mutation Recipe

The canonical pattern for CoW-safe mutation accessors:

```swift
var push: Property<Push> {
    _modify {
        makeUnique()                              // 1. Force uniqueness
        reserve(count + 1)                        // 2. Pre-allocate
        var property: Property<Push> = Property(self)
        self = Container()                        // 3. Release reference
        defer { self = property.base }            // 4. Restore on exit
        yield &property                           // 5. Yield for mutation
    }
}
```

The ordering is critical: `makeUnique()` must precede ownership transfer to prevent the proxy from holding a reference to shared storage.

### 6.2 Migration Statistics

| Package | Before | After | Reduction |
|---------|--------|-------|-----------|
| swift-deque-primitives | 4 proxy structs | 1 typealias | 75% fewer type definitions |
| swift-heap-primitives | 4 proxy structs | 1 typealias | 75% fewer type definitions |
| swift-dictionary-primitives | 2 proxy structs | 1 typealias | 50% fewer type definitions |

---

## 7. Related Work

### 7.1 Lens Libraries

Functional programming languages employ lenses for composable accessors. Swift's `WritableKeyPath` provides similar functionality but lacks the phantom-type-based namespacing that `Property` enables.

### 7.2 Proxy Patterns

The proxy pattern is well-established in object-oriented design. Our contribution is adapting it to Swift's value semantics with explicit CoW support.

### 7.3 Tagged Types

Libraries like `Tagged` (Point-Free) demonstrate phantom types for type-safe wrappers. `Property` extends this concept to accessor namespacing.

---

## 8. Limitations and Future Work

### 8.1 Current Limitations

1. **No abstraction over `yield`**: The `_modify` coroutine pattern cannot be factored into a helper function
2. **Protocol conformance**: The `~Copyable` incompatibility prevents protocol-based extensibility
3. **Nested accessors**: Patterns like `dict.merge.keep` require investigation

### 8.2 Future Work

1. **Compiler investigation**: Filing a bug report for the protocol witness issue with `~Copyable`
2. **Macro-based generation**: Exploring Swift macros to generate the boilerplate `_modify` accessor
3. **Additional migrations**: Completing migration of Heap and Dictionary types

---

## 9. Conclusion

We have presented `Property<Tag, Base>`, a unified type family for fluent API accessors in Swift. By identifying three distinct accessor patterns and providing appropriate abstractions for each, we reduce implementation complexity while preserving Swift's ownership semantics.

Our investigation revealed a fundamental incompatibility between Swift's protocol witness system and `~Copyable` types using coroutine accessors. This finding led to a pragmatic design decision favoring concrete type extensions, prioritizing immediate functionality over speculative future-proofing.

The recommended typealias pattern (`Property<Tag>` with `.Typed<Element>` appended as needed) balances ergonomics with explicitness, making the distinction between method and property extensions clear at declaration sites.

The `Property` type family is available as part of swift-property-primitives under the Apache 2.0 license.

---

## References

1. Apple Inc. "The Swift Programming Language: Memory Safety." Swift Documentation, 2024.
2. Apple Inc. "Ownership Manifesto." Swift Evolution, SE-0377, 2022.
3. Point-Free. "Tagged: A wrapper type for safer, more expressive code." GitHub, 2023.
4. McBride, C. "Clowns to the Left of me, Jokers to the Right: Dissecting Data Structures." POPL, 2008.
5. ten Thije Boonkkamp, C. "swift-primitives: Atomic building blocks for Swift." Swift Institute, 2024.

---

## Appendix A: Complete Type Definitions

> **Snapshot note (2026-04-20):** this inventory reflects the January 2026 state — the paper's original scope of `Property` and `Property.Typed`. For the 2026-04-20 variant expansion — `Property.Consuming`, `Property.View`, `Property.View.Typed`, `Property.View.Read`, `Property.View.Read.Typed`, and the `.Valued` / `.Valued.Valued` value-generic suffixes — see [`variant-decomposition-rationale.md`](variant-decomposition-rationale.md) and the per-type `.docc` catalogues under `Sources/*/{...}.docc/`. The canonical current inventory lives in those surfaces; this appendix is preserved as a research record.

```swift
public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self._base = base
    }

    @inlinable
    public var base: Base {
        _read { yield _base }
        _modify { yield &_base }
    }
}

extension Property: Copyable where Base: Copyable {}
extension Property: Sendable where Base: Sendable {}

extension Property where Base: ~Copyable {
    public struct Typed<Element>: ~Copyable {
        @usableFromInline
        internal var _base: Base

        @inlinable
        public init(_ base: consuming Base) {
            self._base = base
        }

        @inlinable
        public var base: Base {
            _read { yield _base }
            _modify { yield &_base }
        }
    }
}

extension Property.Typed: Copyable where Base: Copyable {}
extension Property.Typed: Sendable where Base: Sendable {}
```

---

## Appendix B: Experiment Repository

The protocol extension investigation is preserved as an executable experiment:

```
swift-property-primitives/
└── Experiments/
    └── property-protocol-test/
        ├── Package.swift
        └── Sources/Test/main.swift
```

Status: **CONFIRMED BUT DISCARDED** — pattern works for `Copyable` types but is incompatible with `~Copyable` support.
