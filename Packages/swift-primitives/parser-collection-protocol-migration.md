# Parser Collection Protocol Migration

<!--
---
version: 2.1.0
last_updated: 2026-02-13
status: DECISION
---
-->

## Context

Parser-primitives contains 8 parsers constrained on stdlib `Collection`:

| Parser | Constraint | APIs Used |
|--------|-----------|-----------|
| `Parser.End` | `Collection` | `isEmpty`, `count` |
| `Parser.Rest` | `Collection, SubSequence == Self` | `endIndex`, range subscript |
| `Parser.Prefix.While` | `Collection, SubSequence == Self` | `startIndex`, `endIndex`, `subscript(pos)`, `formIndex(after:)`, range subscript |
| `Parser.Prefix.UpTo` | `Collection, SubSequence == Self` | same as While |
| `Parser.Prefix.Through` | `Collection, SubSequence == Self` | same as While |
| `Parser.Consume.Exactly` | `Collection, SubSequence == Self` | `index(_:offsetBy:limitedBy:)`, `distance(from:to:)`, range subscript |
| `Parser.Discard.Exactly` | `Collection, SubSequence == Self` | same as Consume.Exactly |
| `Parser.Protocol` convenience | `Collection` | `isEmpty`, `count` |

Stdlib `Collection` does not support `~Copyable` elements. Collection-primitives provides `Collection.Protocol` which does, but lacks slicing, `formIndex(after:)`, and index arithmetic. Parser-primitives is Layer 1 infrastructure and should use its own protocols.

## Question

What protocol constraint should replace stdlib `Collection` in parser-primitives?

## Analysis

### Inventory: What Parsers Need from stdlib Collection

Five distinct capabilities:

1. **Index navigation** — `startIndex`, `endIndex`, `index(after:)`, element access by position
2. **In-place index mutation** — `formIndex(after: &i)`
3. **Index arithmetic** — `index(_:offsetBy:limitedBy:)`, `distance(from:to:)`
4. **Emptiness/count** — `isEmpty`, `count`
5. **Self-slicing** — `subscript(Range<Index>) -> Self`, `subscript(PartialRangeFrom<Index>) -> Self`

### What Collection.Protocol Already Provides

`Collection.Protocol` (collection-primitives) provides capabilities 1 and 4:

| API | Source |
|-----|--------|
| `startIndex: Index` | Protocol requirement |
| `endIndex: Index` | Protocol requirement |
| `subscript(position: Index) -> Element` | Protocol requirement |
| `index(after i: Index) -> Index` | Protocol requirement |
| `makeIterator()` | Inherited from `Sequence.Protocol` |
| `isEmpty: Bool` | Extension on `Collection.Indexed` |
| `count` | Extension via `Collection.Count.View` (typed, not Int) |

### Gaps

| Missing API | Used By | Difficulty |
|-------------|---------|------------|
| `formIndex(after: &i)` | Prefix.While/UpTo/Through | **Trivial**: `i = index(after: i)` |
| `index(_:offsetBy:limitedBy:)` | Consume/Discard.Exactly | **Moderate**: O(n) loop over `index(after:)` |
| `distance(from:to:)` | Consume/Discard.Exactly | **Moderate**: O(n) loop over `index(after:)` |
| `subscript(Range<Index>) -> Self` | All except End | **Requires new protocol** |
| `subscript(PartialRangeFrom<Index>) -> Self` | All slicing parsers | Built from Range subscript |

The first three are derivable from `index(after:)` and can be added as default extensions. The slicing subscript is the fundamental gap.

### Input.Slice as Primary Consumer

`Input.Slice<Base: Collection.Protocol>` from input-primitives is the canonical input type for parsers. It stores:

- `base: Base` — shared underlying collection
- `sliceStart: Base.Index` — fixed start bound
- `sliceEnd: Base.Index` — fixed end bound
- `position: Index<Base.Element>` — current cursor position (typed, relative to slice start)

`Input.Slice` is **Copyable** and **naturally self-slicing**: a sub-slice creates a new `Input.Slice` with narrowed bounds over the same base. This makes it the ideal type for parsers that need `SubSequence == Self`.

Currently `Input.Slice` conforms to `Input.Protocol` but NOT to `Collection.Protocol`. Adding `Collection.Protocol` conformance is feasible — the collection view exposes elements from `position` to `endIndex`, using the typed index coordinate system.

---

### Option A: Add `Collection.Slice.Protocol` to collection-primitives (Recommended)

Add a self-slicing protocol following the standard `Namespace.Protocol` naming convention
and the `Property<Tag, Self>.View` accessor pattern from property-primitives.

#### Design

`Collection.Slice` serves as both:
1. **Namespace/tag** — an enum housing `Collection.Slice.Protocol` (like `Sequence.Iterator` houses `Sequence.Iterator.Protocol`)
2. **Property.View tag** — enabling `.slice` accessor with additional operations via `Property<Collection.Slice, Self>.View`

This follows the established pattern used by `Sequence.Prefix`, `Sequence.Drop`,
`Collection.ForEach`, `Collection.Count`, etc.

#### In collection-primitives

**File: `Collection.Slice.swift`** — Tag + namespace:

```swift
extension Collection {
    /// Tag type for `.slice` property extensions.
    ///
    /// Also serves as namespace for `Collection.Slice.Protocol`.
    public enum Slice {}
}
```

**File: `Collection.Slice.Protocol.swift`** — Protocol:

```swift
extension Collection.Slice {
    /// A collection that can produce sub-ranges of itself.
    ///
    /// The sole requirement is a range subscript returning `Self`.
    /// Partial-range subscripts and index arithmetic are provided
    /// as default extensions.
    public protocol `Protocol`: Collection.`Protocol` & ~Copyable {
        subscript(bounds: Range<Index>) -> Self { get }
    }
}
```

**File: `Collection.Slice.Protocol+defaults.swift`** — Two-tier default extensions:

```swift
// Tier 1: ~Copyable (borrowing access via _read)
// Yields a borrow — callers can read properties, pass to borrowing parameters.
// For Copyable conformers, shadowed by Tier 2.
extension Collection.Slice.`Protocol` where Self: ~Copyable {
    @inlinable
    public subscript(bounds: PartialRangeFrom<Index>) -> Self {
        _read { yield self[bounds.lowerBound..<endIndex] }
    }

    @inlinable
    public subscript(bounds: PartialRangeUpTo<Index>) -> Self {
        _read { yield self[startIndex..<bounds.upperBound] }
    }
}

// Tier 2: Copyable (owned access via get)
// Returns independently-owned slice. Shadows Tier 1 for Copyable conformers.
extension Collection.Slice.`Protocol` {
    @inlinable
    public subscript(bounds: PartialRangeFrom<Index>) -> Self {
        self[bounds.lowerBound..<endIndex]
    }

    @inlinable
    public subscript(bounds: PartialRangeUpTo<Index>) -> Self {
        self[startIndex..<bounds.upperBound]
    }
}
```

> **Compiler limitation (Swift 6.2.3)**: Protocol dispatch for `~Copyable Self`
> returning `Self` via `get` fails with "self.subscript is borrowed and cannot
> be consumed." This only affects protocol extension defaults — concrete types
> can forward subscripts freely. The two-tier `_read`/`get` pattern mirrors
> the `borrowing` closure pattern used in sequence-primitives. `~Copyable`
> conformers needing owned partial-range access implement directly on the
> concrete type. See experiment: `swift-collection-primitives/Experiments/self-slicing-noncopyable/`.

**Also in `Collection.Indexed.swift`** — `formIndex(after:)` default:

```swift
// Index mutation derived from index(after:)
extension Collection.Indexed where Self: ~Copyable {
    @inlinable
    public func formIndex(after i: inout Index) {
        i = index(after: i)
    }
}
```

**File: `Collection.Slice.Protocol+Slice.swift`** — Property.View accessor:

```swift
extension Collection.Slice.`Protocol` where Self: ~Copyable {
    @inlinable
    public var slice: Property<Collection.Slice, Self>.View {
        mutating _read {
            yield unsafe Property<Collection.Slice, Self>.View(&self)
        }
    }
}
```

**File: `Collection.Slice+Property.View.swift`** — Operations via Property.View:

```swift
extension Property.View
where Base: Collection.Slice.`Protocol` & ~Copyable, Tag == Collection.Slice {
    // Future expansion: prefix(count:), suffix(count:), split, etc.
    // These build on the required Range subscript + existing
    // startIndex/endIndex from Collection.Protocol.
}
```

#### Call-site syntax

Parsers use the **protocol subscripts directly** — no `.slice` intermediary for basic operations:

```swift
let result = input[input.startIndex..<endIndex]   // Range subscript (protocol req.)
input = input[endIndex...]                         // PartialRangeFrom (default ext.)
```

The `.slice` accessor is available for additional operations:

```swift
let prefix = input.slice.first(Cardinal(10))       // via Property.View
```

#### In input-primitives

```swift
// Sequence.Protocol conformance
extension Input.Slice: Sequence.`Protocol` where Base.Element: Copyable {
    public typealias Iterator = /* position-based iterator */
    public borrowing func makeIterator() -> Iterator { ... }
}

// Collection.Protocol conformance
extension Input.Slice: Collection.`Protocol` where Base.Element: Copyable {
    public var startIndex: Index<Element> { position }
    public var endIndex: Index<Element> { totalCount.map(Ordinal.init) }

    public subscript(position idx: Index<Element>) -> Element {
        base[sliceStart + Index<Element>.Count(idx)]
    }

    public func index(after i: Index<Element>) -> Index<Element> {
        try! i.successor.exact()
    }
}

// Collection.Slice.Protocol conformance (self-slicing)
extension Input.Slice: Collection.Slice.`Protocol` where Base.Element: Copyable {
    public subscript(bounds: Range<Index<Element>>) -> Self {
        let newStart = sliceStart + Index<Element>.Count(bounds.lowerBound)
        let newEnd = sliceStart + Index<Element>.Count(bounds.upperBound)
        return Input.Slice(__unchecked: (), base: base,
                           startIndex: newStart, endIndex: newEnd)
    }
}
```

`Input.Slice` automatically inherits:
- Partial-range subscripts from `Collection.Slice.Protocol` defaults
- `formIndex(after:)` from `Collection.Indexed` extension
- `.slice` Property.View accessor for additional operations
- `.forEach`, `.count`, `.contains`, etc. from `Collection.Protocol` extensions

#### In parser-primitives

```swift
// Change from:
public struct While<Input: Collection>: Sendable
where Input: Sendable, Input.SubSequence == Input { ... }

// To:
public struct While<Input: Collection.Slice.`Protocol`>: Sendable
where Input: Sendable { ... }
```

#### Evaluation

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Architectural fit | Excellent | Slicing is a collection concept; follows Nest.Name pattern |
| Naming convention | Excellent | `Collection.Slice.Protocol` mirrors `Sequence.Iterator.Protocol` |
| Property.View pattern | Excellent | Standard tag + `Property<Tag, Self>.View` reuse |
| ~Copyable support | Full | Protocol is `& ~Copyable` |
| Zero-copy preservation | Full | Sub-slicing shares base |
| Migration effort | Moderate | 3 packages need changes |
| Backward compatibility | Good | stdlib bridge provides Swift.Collection for free |
| Reusability | High | Any self-slicing collection benefits |
| Extensibility | High | `.slice` Property.View allows future operations |

---

### Option B: Add `Input.Collection` to input-primitives

Create a protocol that combines Input.Protocol + collection access + slicing, local to input-primitives.

```swift
extension Input {
    /// Input that supports collection-style indexed access and slicing.
    public protocol Collection: Input.`Protocol` {
        var startIndex: Index<Element> { get }
        var endIndex: Index<Element> { get }
        subscript(position: Index<Element>) -> Element { get }
        func index(after i: Index<Element>) -> Index<Element>
        subscript(bounds: Range<Index<Element>>) -> Self { get }
    }
}
```

**Evaluation:**

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Architectural fit | Poor | Duplicates collection concepts in input layer |
| ~Copyable support | Partial | Tied to Input.Protocol which requires Copyable elements for first? |
| Zero-copy preservation | Full | Same sub-slicing approach |
| Migration effort | Low | Only input-primitives + parser-primitives |
| Backward compatibility | Poor | No stdlib bridge |
| Reusability | Low | Only useful for input/parsing |

---

### Option C: Rewrite parsers to use Input.Protocol with output type changes

Change slicing parsers to use checkpoint/advance instead of subscript/slice. Output types change from `Input` to `[Element]` or checkpoint pairs.

```swift
// Parser.Prefix.While would become:
extension Parser.Prefix.While: Parser.`Protocol` {
    public typealias ParseOutput = [Input.Element]  // was: Input

    public func parse(_ input: inout Input) throws(Failure) -> ParseOutput {
        var result: [Input.Element] = []
        while !input.isEmpty {
            let cp = input.checkpoint
            let element = try! input.advance()
            guard predicate(element) else {
                input.setPosition(to: cp)
                break
            }
            result.append(element)
        }
        // ...
        return result
    }
}
```

**Evaluation:**

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Architectural fit | Good | Parsers fully in input-protocol world |
| ~Copyable support | Full | No collection dependency |
| Zero-copy preservation | **None** | Allocates array for every prefix parse |
| Migration effort | High | Changes parser API semantics |
| Backward compatibility | **Breaking** | Output types change |
| Reusability | N/A | No reusable protocol added |

---

## Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Arch. fit | ★★★ | ★☆☆ | ★★☆ |
| ~Copyable | ★★★ | ★★☆ | ★★★ |
| Zero-copy | ★★★ | ★★★ | ☆☆☆ |
| Migration | ★★☆ | ★★★ | ★☆☆ |
| Compat. | ★★★ | ★☆☆ | ☆☆☆ |
| Reuse | ★★★ | ★☆☆ | ☆☆☆ |

## Outcome

**Status**: DECISION

**Decision**: Option A — Add `Collection.Slice.Protocol` to collection-primitives using the standard Property.View pattern.

**Rationale:**

1. **Naming convention compliance** — `Collection.Slice.Protocol` follows the established `Namespace.Protocol` pattern (`Sequence.Iterator.Protocol`, `Collection.Protocol`, `Input.Protocol`). The rejected `Collection.Sliceable` name violates [API-NAME-001] Nest.Name.
2. **Property.View reuse** — `Collection.Slice` serves as both namespace and tag, enabling `.slice` accessor via `Property<Collection.Slice, Self>.View` exactly like `Sequence.Prefix`, `Sequence.Drop`, `Collection.ForEach`.
3. **Slicing is a collection concept** — belongs in collection-primitives, not input-specific.
4. **Self-slicing** — `subscript(Range) -> Self` directly models what parsers need: `SubSequence == Self` without the associated type complexity.
5. **Hierarchy unification** — `Input.Slice` gaining `Collection.Protocol` + `Collection.Slice.Protocol` conformance unifies collection-style access and input-style cursor navigation.
6. **Stdlib bridge** — `Collection.Protocol where Self: Copyable` → `Swift.Collection` means `Input.Slice` gets stdlib Collection for free.
7. **Zero-copy preservation** — sub-slicing `Input.Slice` shares the underlying `base`.
8. **Extensibility** — `.slice` Property.View accessor provides a standard extension point for future operations (prefix by count, suffix, split, etc.) without modifying the protocol.

**Implementation plan:**

| Step | Package | Changes |
|------|---------|---------|
| 1 | **collection-primitives** | Add `Collection.Slice` enum, `Collection.Slice.Protocol`, default extensions (partial-range subscripts, `formIndex(after:)`), `.slice` Property.View accessor |
| 2 | **input-primitives** | Add `Sequence.Protocol`, `Collection.Protocol`, and `Collection.Slice.Protocol` conformances to `Input.Slice` |
| 3 | **parser-primitives** | Change `Input: Collection where SubSequence == Input` → `Input: Collection.Slice.Protocol` across 8 parsers |

**File plan for collection-primitives (Step 1):**

| File | Contents |
|------|----------|
| `Collection.Slice.swift` | Tag enum: `extension Collection { public enum Slice {} }` |
| `Collection.Slice.Protocol.swift` | Protocol: `subscript(bounds: Range<Index>) -> Self` |
| `Collection.Slice.Protocol+defaults.swift` | Partial-range subscripts, `formIndex(after:)` |
| `Collection.Slice.Protocol+Slice.swift` | `.slice` Property.View accessor |
| `Collection.Slice+Property.View.swift` | Operations via `Property.View where Tag == Collection.Slice` |

**Additional requirement**: collection-primitives needs `.enableExperimentalFeature("SuppressedAssociatedTypes")` since it inherits `Element: ~Copyable` from sequence-primitives.

**Two-tier partial-range defaults**: Due to a Swift 6.2.3 compiler limitation where protocol dispatch for `~Copyable Self` returning `Self` via `get` fails, the partial-range subscript defaults use a two-tier pattern: `_read` for `~Copyable` (borrowing access) and `get` for `Copyable` (owned access). This mirrors the `borrowing` closure two-tier pattern in sequence-primitives. See experiment: `self-slicing-noncopyable`.

**Typed count bridge**: `Parser.Match.Error.expectedEnd(remaining: Int)` needs typed count → Int conversion. Use `Int(bitPattern:)` from ordinal-primitives conversion infrastructure.

## References

- `swift-collection-primitives/Sources/Collection Primitives/Collection.Protocol.swift`
- `swift-collection-primitives/Sources/Collection Primitives/Collection.Indexed.swift` (isEmpty, index navigation)
- `swift-collection-primitives/Sources/Collection Primitives/Collection.Protocol+Swift.Collection.swift` (stdlib bridge)
- `swift-input-primitives/Sources/Input Primitives/Input.Slice.swift`
- `swift-input-primitives/Sources/Input Primitives/Input.Slice+Input.Protocol.swift`
- `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Prefix.swift` (Property.View tag pattern)
- `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Protocol+Prefix.swift` (accessor pattern)
- `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Prefix+Property.View.swift` (implementation pattern)
- `swift-property-primitives/Sources/Property Primitives/Property.View.swift` (Property.View infrastructure)
- Parser source files: `Parser.{End,Rest,Prefix.While,Prefix.UpTo,Prefix.Through,Consume.Exactly,Discard.Exactly}.swift`
- `swift-collection-primitives/Experiments/self-slicing-noncopyable/` (two-tier default validation)
- `swift-sequence-primitives/Research/sequence-protocol-noncopyable-elements.md` (SuppressedAssociatedTypes decision)
