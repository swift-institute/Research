# Set Protocol Abstraction

<!--
---
version: 1.0.0
last_updated: 2026-03-02
status: IN_PROGRESS
tier: 2
---
-->

## Context

swift-set-primitives provides four ordered set variants (`Set.Ordered`, `.Fixed`, `.Static`, `.Small`), each implementing `contains`, `insert`, `remove`, and iteration independently. There is no shared protocol — unlike `Array.Protocol` in swift-array-primitives, which unifies all four array variants behind a single abstraction.

**Trigger**: During the `Set<String>` → `Set<String>.Ordered` migration in swift-tests, `isDisjoint(with:)` (available on `Swift.Set`) was needed but missing from our set types. The workaround — `tags.contains(where: { entryTags.contains($0) })` — is correct but verbose. The question is whether a `Set.Protocol` could provide `isDisjoint` (and similar query operations) as default implementations, the way `Swift.SetAlgebra` does.

**Precedent**: `Array.Protocol` (`__ArrayProtocol`) in swift-array-primitives successfully unifies all four array variants behind `subscript` + `Collection.Bidirectional` inheritance. All variants conform with a single empty extension. Default implementations for `forEach`, `withElement(at:_:)`, and Property.View integration flow from the protocol.

## Question

Should we create a `Set.Protocol` that our set types conform to, providing `isDisjoint(with:)` and other set query operations as default implementations?

## Analysis

### Prior Art

**Swift.SetAlgebra** requires:
- `contains(_:) -> Bool` (non-mutating)
- `union(_:) -> Self`, `intersection(_:) -> Self`, `symmetricDifference(_:) -> Self`
- `insert(_:) -> (inserted: Bool, memberAfterInsert: Element)`
- `remove(_:) -> Element?`, `update(with:) -> Element?`
- `init()`, `Equatable`, `ExpressibleByArrayLiteral`

Default implementations: `isSubset(of:)`, `isSuperset(of:)`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`, `isDisjoint(with:)`, `subtract(_:)`, `formUnion(_:)`, `formIntersection(_:)`, `formSymmetricDifference(_:)`, `isEmpty`.

**Rust** `std::collections::HashSet`: `is_disjoint(&self, other: &HashSet) -> bool` — iterates the smaller set, probes the larger. No shared trait; it's a concrete method.

**Array.Protocol** (our precedent): Declared as `__ArrayProtocol` at module scope (hoisted per nested-protocols-in-generic-types research — Swift prohibits protocols inside generic types), aliased via `Array.Protocol`. Requires `subscript` + `Collection.Bidirectional` inheritance. All four array variants conform.

### Constraint Inventory

Before evaluating options, the constraints that make this non-trivial:

| Constraint | Description | Affected Variants |
|------------|-------------|-------------------|
| **C1**: `contains` mutating on Small | `Small.contains` is `mutating` (exclusivity workaround for `~Copyable` generics) | Small |
| **C2**: `insert` throws on Fixed/Static | `Fixed.insert` throws `__SetOrderedFixedError`, `Static.insert` throws `__SetOrderedInlineError` | Fixed, Static |
| **C3**: Different error types | Each variant has its own error type for bounds/overflow | All |
| **C4**: ~Copyable unconditional on Static/Small | Static and Small have `deinit`, cannot be Copyable | Static, Small |
| **C5**: Algebra only on Ordered | Set algebra operations (`union`, `intersection`, etc.) currently only exist on `Set.Ordered` | Fixed, Static, Small |
| **C6**: Hoisted protocol requirement | Swift cannot nest protocols in generic types (`Set<Element>`) | All |

**C1 is the critical constraint.** A protocol with `func contains(_:) -> Bool` (non-mutating) cannot be satisfied by `Small.contains` (mutating). Either Small must fix its `contains` signature, or the protocol must accommodate mutating containment checks.

Small's `contains` calls `index(_:)`, which is mutating. The mutation isn't semantic — it's a compiler workaround for exclusivity analysis on `~Copyable` generic stored properties. The `_heapHashTable` access in spilled mode triggers false exclusivity violations if non-mutating. This may be fixable in future Swift versions, but today it's a hard constraint.

### Option A: Full Set.Protocol (mirrors SetAlgebra)

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.Protocol & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    var count: Index<Element>.Count { get }
    var isEmpty: Bool { get }
}

extension Set where Element: ~Copyable {
    public typealias `Protocol` = __SetProtocol
}
```

Default implementations on `Set.Protocol`:
- `isDisjoint(with:)` — requires iteration + contains
- `isSubset(of:)`, `isSuperset(of:)` — require iteration + contains
- `isEmpty` — default via `count == .zero`

**Pros**:
- Clean parallel to `Array.Protocol`
- `isDisjoint`, `isSubset`, `isSuperset` become free
- Generic programming over any set variant

**Cons**:
- **Small cannot conform** (C1: mutating `contains`)
- Full SetAlgebra-style requirements (`union`, `intersection`) hit C2 (throwing insert) and C5 (only on Ordered)
- Algebra operations return `Self`, but our algebra returns `Set.Ordered` always

**Verdict**: C1 blocks Small. If Small's `contains` were non-mutating, this would be the ideal option.

### Option B: Minimal Query Protocol (contains-only)

Same as Option A but with the absolute minimum:

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.Protocol & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
}
```

Only `isDisjoint` and similar pure-query operations as defaults (via `Sequence.Protocol` for iteration).

**Pros**:
- Minimal requirement surface
- `isDisjoint` falls out naturally
- No algebra complexity

**Cons**:
- **Still blocked by C1** — Small's mutating `contains`
- So minimal it might not justify a protocol

**Verdict**: Same C1 blocker. Slightly better than A but same fundamental problem.

### Option C: Protocol with mutating contains

Accommodate Small by making `contains` mutating in the protocol:

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.Protocol & ~Copyable
    mutating func contains(_ element: borrowing Element) -> Bool
}
```

Ordered, Fixed, Static satisfy this (non-mutating satisfies mutating requirement). Small satisfies directly.

**Pros**:
- All four variants can conform
- `isDisjoint` works (both sides need `var` binding)

**Cons**:
- Protocol forces `var` bindings at every call site: `var set = ...; set.contains(x)` even for Ordered/Fixed where mutation is unnecessary
- Violates user expectations — `contains` is universally non-mutating in Swift
- Default implementations for `isDisjoint` would need `inout self` or `inout other`
- Makes generic code awkward: `func check<S: Set.Protocol>(s: inout S) { s.contains(x) }`

**Verdict**: Technically works but the ergonomic cost is severe. A mutating `contains` is a design smell.

### Option D: Concrete extensions (no protocol)

Add `isDisjoint` directly to each concrete type:

```swift
// On Set.Ordered (non-mutating contains, Swift.Sequence)
extension Set.Ordered where Element: Copyable {
    public func isDisjoint(with other: borrowing Self) -> Bool {
        for element in self {
            if other.contains(element) { return false }
        }
        return true
    }
}

// On Set.Ordered.Fixed (non-mutating contains, Swift.Sequence)
extension Set.Ordered.Fixed where Element: Copyable {
    public func isDisjoint(with other: borrowing Self) -> Bool {
        for element in self {
            if other.contains(element) { return false }
        }
        return true
    }
}

// On Set.Ordered.Small (mutating contains, Sequence.Protocol)
extension Set.Ordered.Small where Element: Copyable {
    public mutating func isDisjoint(with other: inout Self) -> Bool {
        var disjoint = true
        forEach { element in
            if other.contains(element) { disjoint = false }
        }
        return disjoint
    }
}
```

**Pros**:
- No protocol needed — zero abstraction overhead
- Each variant gets the ideal signature (non-mutating for Ordered/Fixed, mutating for Small)
- Can ship today without resolving the `contains` mutability question
- Heterogeneous overloads possible: `Set.Ordered.isDisjoint(with other: Set.Ordered.Fixed)`

**Cons**:
- Code duplication across variants
- No generic programming over "any set"
- Each new query operation must be added to each variant separately

**Verdict**: Pragmatic. Ships the feature without architectural commitment.

### Option E: Fix Small's contains, then Option B

The root cause of C1 is a compiler workaround, not a semantic requirement. If `Small.contains` and `Small.index` can be made non-mutating (by restructuring the `_heapHashTable` access), then Option B becomes viable.

Steps:
1. Investigate whether `Small.index` can be non-mutating (the linear scan path doesn't mutate; the hash table path uses `_heapHashTable!.position(...)` which is a non-mutating read)
2. If the exclusivity bug only manifests under specific patterns, restructure to avoid it
3. Once non-mutating, declare `Set.Protocol` per Option B
4. All four variants conform

**Pros**:
- Fixes the real problem (unnecessary `mutating` annotation)
- Unlocks clean protocol abstraction
- `isDisjoint` becomes a protocol default
- Small's API improves (callers no longer need `var` for `contains`)

**Cons**:
- Depends on compiler workaround resolution
- May require experiment to validate non-mutating access doesn't crash
- Blocks protocol on compiler investigation

**Verdict**: Best long-term option, but requires validation.

### Comparison

| Criterion | A: Full | B: Minimal | C: Mutating | D: Concrete | E: Fix + B |
|-----------|---------|------------|-------------|-------------|------------|
| All variants conform | No (Small) | No (Small) | Yes | N/A | Yes |
| isDisjoint as default | Yes | Yes | Yes | Manual | Yes |
| Ergonomic contains | Yes | Yes | No (mutating) | Mixed | Yes |
| Ships today | No | No | Yes | Yes | Maybe |
| Generic set programming | Yes | Yes | Yes (awkward) | No | Yes |
| Code duplication | None | None | None | 4× per operation | None |
| Parallel to Array.Protocol | Full | Partial | Partial | None | Partial |
| Resolves root cause | No | No | No | No | Yes |

## Outcome

**Status**: IN_PROGRESS

### C1 Resolved (2026-03-02)

`Small.index` and `Small.contains` were changed from `mutating` to non-mutating.
Build + all 59 tests pass. The `mutating` was legacy — no exclusivity issue exists.
`Hash.Table.position(forHash:equals:)` is `borrowing`, `Buffer.Linear.Small`
subscript/count/isSpilled are all non-mutating. The closure capture
`{ idx in _buffer[idx] == element }` is a pure read.

**C1 is eliminated.** All four variants now have non-mutating `contains`.

### Recommended Path

**Option B**: Minimal `Set.Protocol` with `contains` as sole requirement. Default implementations for `isDisjoint`, `isSubset`, `isSuperset` via `Sequence.Protocol` iteration. Hoisted as `__SetProtocol` per the nested-protocols-in-generic-types research.

### Open Questions

1. **Should `isDisjoint` accept heterogeneous set types?** E.g., `Set.Ordered.isDisjoint(with: Set.Ordered.Fixed)`. With a protocol, this is `<Other: Set.Protocol>`. Without, each pair needs an overload.
2. **Should algebra operations move to the protocol?** They currently only exist on `Set.Ordered` and always return `Set.Ordered`. A protocol would need `associatedtype` for return type, adding complexity.
3. **Should `Set.Protocol` inherit from `Sequence.Protocol`?** `Array.Protocol` inherits from `Collection.Bidirectional`. The set equivalent would be `Sequence.Protocol` (sets have no inherent ordering for bidirectional traversal, even though our ordered sets do preserve insertion order).

## References

- swift-array-primitives `Array.Protocol`: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.Protocol.swift`
- swift-set-primitives algebra: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Algebra.swift`
- Nested protocols research: `swift-institute/Research/nested-protocols-in-generic-types.md`
- Small exclusivity workaround: `Set.Ordered.Small.swift:117-124`
- Swift.SetAlgebra: stdlib `SetAlgebra.swift`
