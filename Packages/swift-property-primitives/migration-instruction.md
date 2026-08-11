# Property Type Migration Instruction
<!--
---
version: 1.0.0
last_updated: 2026-01-21
status: IMPLEMENTED
---
-->

You are tasked with migrating fluent API accessor patterns to use the unified `Property<Tag, Base>` type family from swift-property-primitives.

## Context

I am providing you with:
1. **This instruction document** — migration steps and patterns
2. **Technical paper** — "Property Type Family: A Unified Abstraction for Fluent API Accessors in Swift"
3. **Migration inventory** — list of packages and accessors to migrate

Read the technical paper first to understand the design rationale and patterns.

## Migration Pattern

For each accessor in the inventory, follow this pattern:

### Step 1: Add Property Typealias

In a file named `{Type}.Property.swift`:

```swift
import Property_Primitives

extension {Type} where Element: Copyable {
    /// Shorthand for `Property_Primitives.Property<Tag, {Type}<Element>>`.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, {Type}<Element>>
}
```

### Step 2: Define Tag (if not exists)

Keep the existing tag enum in its own file:

```swift
extension {Type} where Element: Copyable {
    /// Phantom tag for {operation} operations.
    public enum {Operation} {}
}
```

### Step 3: Update Accessor Return Type

**For method-only accessors** (push, pop):
```swift
public var {accessor}: Property<{Tag}> {
    _read { ... }
    _modify { ... }
}
```

**For property accessors** (peek, take):
```swift
public var {accessor}: Property<{Tag}>.Typed<Element> {
    // read-only or _modify as appropriate
}
```

### Step 4: Update Extensions

**Before (concrete proxy type):**
```swift
extension {Type}.{Operation} {
    public mutating func back(_ element: Element) { ... }
}
```

**After (Property extension):**
```swift
extension Property_Primitives.Property {
    @inlinable
    public mutating func back<E: Copyable>(_ element: E)
    where Tag == {Type}<E>.{Operation}, Base == {Type}<E> {
        base.{underlyingMethod}(element)
    }
}
```

**For property extensions:**
```swift
extension Property_Primitives.Property.Typed
where Tag == {Type}<Element>.{Operation}, Base == {Type}<Element>, Element: Copyable {
    @inlinable
    public var back: Element? {
        base.{underlyingMethod}()
    }
}
```

### Step 5: Remove Old Proxy Struct

Delete the old proxy struct definition (e.g., `struct Push { var base: {Type} }`).

### Step 6: Update Accessor Implementation

The `_modify` accessor pattern remains the same:

```swift
_modify {
    makeUnique()
    reserve(count + 1)  // if applicable
    var property: Property<{Tag}> = Property(self)
    self = {Type}()
    defer { self = property.base }
    yield &property
}
```

## Checklist Per Accessor

- [ ] Property typealias exists (one per package)
- [ ] Tag enum preserved
- [ ] Accessor return type updated
- [ ] Extensions moved to Property/Property.Typed
- [ ] Old proxy struct removed
- [ ] Package builds
- [ ] Tests pass

## Reference Implementation

See swift-deque-primitives for the completed migration:
- `Deque.Property.swift` — typealias definition
- `Deque.Push.swift` — method accessor example
- `Deque.Peek.swift` — property accessor example
- `Deque.Take.swift` — mutating property accessor example

## Important Notes

1. **Keep `@inlinable`** on all accessor implementations
2. **Keep `@usableFromInline`** on internal storage
3. **Preserve existing documentation** on public APIs
4. **Run tests** after each accessor migration
5. **One commit per package** for clean history

## Migration Order (Recommended)

1. swift-heap-primitives (4 accessors, similar to Deque)
2. swift-dictionary-primitives (2 accessors)

## Do NOT Migrate

The following patterns have different semantics and should remain as concrete types:
- `Numeric.Math.Accessor<T>` — type dispatch token
- `Binary.Parse.Access<P>` — namespace wrapper
- `Terminal.Mode.Access` — namespace wrapper
- `Async.Channel.Bounded.Take` — consuming accessor
- `Parser.Peek<Upstream>` — parser combinator

## Questions to Ask Before Starting

1. Does the package have a dependency on Property_Primitives? If not, add it.
2. Are there any tests for the accessors? Ensure they pass after migration.
3. Are there nested accessors (e.g., `merge.keep`)? These need special handling.
