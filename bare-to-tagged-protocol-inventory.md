# Bare-to-Tagged Protocol Inventory

Inventory of all protocol **declarations** that use bare `Cardinal` or `Ordinal` types in their requirements. Only protocol bodies are considered -- conformances, extensions, and default implementations are excluded.

**Scope**: swift-primitives, swift-standards, swift-foundations

**Date**: 2026-03-20

---

## Summary

| Repository | Protocols with bare Cardinal/Ordinal | Notes |
|---|---|---|
| swift-primitives | 5 active protocols | All in L1 primitives |
| swift-standards | 0 | Uses tagged types throughout |
| swift-foundations | 0 | Uses tagged types throughout |

---

## Inventory

### 1. `Cardinal.Protocol`

| Field | Value |
|---|---|
| **File** | `/Users/coen/Developer/swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` |
| **Lines** | 29--43 |
| **Package** | swift-cardinal-primitives |
| **Declared in** | `extension Cardinal { public protocol Protocol { ... } }` |

**Requirements**:

| Line | Requirement | Bare Type | Semantic Scope |
|---|---|---|---|
| 36 | `associatedtype Domain: ~Copyable` | -- | -- |
| 39 | `var cardinal: Cardinal { get }` | `Cardinal` | Self -- extracts the untyped cardinal from a conformer |
| 42 | `init(_ cardinal: Cardinal)` | `Cardinal` | Self -- constructs from an untyped cardinal |

**Assessment**: Correct. This is the abstraction protocol *for* `Cardinal` itself. Bare `Cardinal` is the canonical representation being abstracted over. The protocol exists to allow `Tagged<Tag, Cardinal>` to expose the underlying bare value. Using tagged types here would be circular.

---

### 2. `Ordinal.Protocol`

| Field | Value |
|---|---|
| **File** | `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift` |
| **Lines** | 35--55 |
| **Package** | swift-ordinal-primitives |
| **Declared in** | `extension Ordinal { public protocol Protocol { ... } }` |

**Requirements**:

| Line | Requirement | Bare Type | Semantic Scope |
|---|---|---|---|
| 42 | `associatedtype Domain: ~Copyable` | -- | -- |
| 48 | `associatedtype Count: Cardinal.Protocol` | -- | Uses `Cardinal.Protocol` (the protocol), not bare `Cardinal` |
| 51 | `var ordinal: Ordinal { get }` | `Ordinal` | Self -- extracts the untyped ordinal from a conformer |
| 54 | `init(_ ordinal: Ordinal)` | `Ordinal` | Self -- constructs from an untyped ordinal |

**Assessment**: Correct. Same rationale as `Cardinal.Protocol` -- this is the abstraction protocol *for* `Ordinal` itself. Bare `Ordinal` is the canonical representation. Using tagged types here would be circular.

---

### 3. `Sequence.Iterator.Protocol`

| Field | Value |
|---|---|
| **File** | `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift` |
| **Lines** | 109--126 |
| **Package** | swift-sequence-primitives |
| **Declared in** | `extension Sequence.Iterator { public protocol Protocol: ~Copyable, ~Escapable { ... } }` |

**Requirements**:

| Line | Requirement | Bare Type | Semantic Scope |
|---|---|---|---|
| 111 | `associatedtype Element: ~Copyable` | -- | -- |
| 125 | `mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>` | `Cardinal` | Domain-free -- maximum batch size is not scoped to any particular element domain |

**Assessment**: Questionable. The `maximumCount` parameter controls how many elements to return. In conformances/call sites, the element type is known, so a tagged `Index<Element>.Count` could provide stronger type safety. However, `maximumCount` is a *request limit*, not a measured property of the collection -- it comes from the caller, who may not have a tagged count in scope. The bare `Cardinal` here acts as a universal "how many" without requiring callers to tag their batch size.

**Trade-off**: If changed to `Index<Element>.Count`, callers would need to construct a tagged count even for literal values like `1` or `256`. The default `next()` extension (line 142) constructs `Cardinal(1)` and would need to become `Index<Element>.Count(...)`. The default `skip(by:)` (line 160) parameter and return type are also bare `Cardinal`.

---

### 4. `Finite.Enumerable`

| Field | Value |
|---|---|
| **File** | `/Users/coen/Developer/swift-primitives/swift-finite-primitives/Sources/Finite Primitives Core/Finite.Enumerable.swift` |
| **Lines** | 36--51 |
| **Package** | swift-finite-primitives |
| **Declared in** | `extension Finite { public protocol Enumerable: CaseIterable, Sendable { ... } }` |

**Requirements**:

| Line | Requirement | Bare Type | Semantic Scope |
|---|---|---|---|
| 38 | `static var count: Cardinal { get }` | `Cardinal` | Self-scoped -- this is the number of inhabitants of `Self`, semantically `Cardinal<Self>` |
| 41 | `var ordinal: Ordinal_Primitives.Ordinal { get }` | `Ordinal` (qualified) | Self-scoped -- this is the ordinal position within `Self`'s inhabitants, semantically `Ordinal<Self>` |
| 50 | `init(__unchecked: Void, ordinal: Ordinal_Primitives.Ordinal)` | `Ordinal` (qualified) | Self-scoped -- constructs from an ordinal position within `Self`'s inhabitant space |

**Assessment**: These are semantically scoped to `Self`. The `count` is the number of values of `Self`, and the `ordinal` is the position of `self` within `Self`'s finite set. Using `Tagged<Self, Cardinal>` and `Tagged<Self, Ordinal>` would be more precise. However, `Finite.Enumerable` conformers are the tag types themselves (e.g., `CardSuit`), so `Tagged<CardSuit, Cardinal>` for `CardSuit.count` would create a circular dependency or at minimum a conceptual oddity where the tag and the conformer are the same type.

Note: line 41 uses the qualified `Ordinal_Primitives.Ordinal`, not the bare import-level `Ordinal`, suggesting awareness of potential ambiguity.

---

### 5. `Finite.Capacity`

| Field | Value |
|---|---|
| **File** | `/Users/coen/Developer/swift-primitives/swift-finite-primitives/Sources/Finite Primitives Core/Finite.Capacity.swift` |
| **Lines** | 10--13 |
| **Package** | swift-finite-primitives |
| **Declared in** | `extension Finite { public protocol Capacity: Sendable { ... } }` |

**Requirements**:

| Line | Requirement | Bare Type | Semantic Scope |
|---|---|---|---|
| 12 | `static var capacity: Cardinal { get }` | `Cardinal` | Self-scoped -- this is the capacity of `Self` as a tag, semantically `Cardinal<Self>` |

**Assessment**: Same situation as `Finite.Enumerable.count`. The `capacity` is the number of valid values that the tag allows. Conformers are tag types (e.g., `Finite.Bound<let N: UInt>` conforms with `capacity = Cardinal(UInt(N))`). The bare `Cardinal` is semantically scoped to the conforming tag type.

---

## Protocols that reference Cardinal/Ordinal but do NOT use bare types in requirements

These protocols appear in source files alongside `Cardinal`/`Ordinal` usage but do not use bare types in their protocol requirements:

| Protocol | File | Uses | Notes |
|---|---|---|---|
| `Algebra.Residual` | `.../Algebra.Residual.swift` | Inherits `Finite.Capacity` | Empty body -- `capacity` requirement inherited from `Finite.Capacity` |
| `Input.Protocol` | `.../Input.Protocol.swift` | `Index<Element>.Count` | Tagged -- uses `Index<Element>.Count` for `count` and `advance(by:)` |
| `Set.Protocol` (`__SetProtocol`) | `.../Set.Protocol.swift` | `Index<Element>.Count` | Tagged -- uses `Index<Element>.Count` for `count` |
| `Collection.Protocol` | `.../Collection.Protocol.swift` | `Index_Primitives.Index<Element>` | Tagged -- uses `Index<Element>` for all index operations |

---

## Cross-cutting analysis

### Classification of bare usage

| Category | Protocols | Assessment |
|---|---|---|
| **Abstraction-over-self** | `Cardinal.Protocol`, `Ordinal.Protocol` | Correct -- bare type is the thing being abstracted. Tagged would be circular. |
| **Domain-free quantity** | `Sequence.Iterator.Protocol` | Debatable -- `maximumCount` is a caller-supplied limit, arguably domain-free |
| **Self-scoped but bare** | `Finite.Enumerable`, `Finite.Capacity` | The count/capacity/ordinal are semantically scoped to `Self`, but using `Tagged<Self, Cardinal>` would create circularity since conformers ARE the tag types |

### Dependency ordering

```
Cardinal.Protocol       (tier 1, swift-cardinal-primitives)
       |
Ordinal.Protocol        (tier 2, swift-ordinal-primitives) -- uses Cardinal.Protocol as associated type
       |
Finite.Capacity         (tier 4, swift-finite-primitives)  -- uses Cardinal
Finite.Enumerable       (tier 4, swift-finite-primitives)  -- uses Cardinal + Ordinal
       |
Sequence.Iterator.Protocol (tier 5, swift-sequence-primitives) -- uses Cardinal
```

### Protocols that successfully use tagged types

For contrast, these protocols demonstrate the tagged pattern:

| Protocol | Requirement | Type Used |
|---|---|---|
| `Collection.Protocol` | `var startIndex: Index` | `Index_Primitives.Index<Element>` (tagged) |
| `Collection.Protocol` | `var endIndex: Index` | `Index_Primitives.Index<Element>` (tagged) |
| `Set.Protocol` | `var count: Index<Element>.Count` | `Index<Element>.Count` = `Tagged<Element, Cardinal>` (tagged) |
| `Input.Protocol` | `var count: Index<Element>.Count` | `Index<Element>.Count` (tagged) |
| `Input.Protocol` | `advance(by: Index<Element>.Count)` | `Index<Element>.Count` (tagged) |
