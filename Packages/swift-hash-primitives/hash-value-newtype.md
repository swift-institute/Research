# Hash Value Newtype

<!--
---
version: 2.0.0
last_updated: 2026-02-07
status: DECISION
research_tier: 2
applies_to: [swift-hash-primitives, swift-hash-table-primitives]
normative: false
---
-->

## Context

`Hash.Protocol.hashValue` returns raw `Int`. This `Int` flows untyped through the entire ecosystem:

- `Hash.Table.insert(position:hashValue:equals:)` accepts `Int`
- `Hash.Table.normalize()` maps sentinels `0 → 1`, `Int.min → 1`
- Storage layers store hashes as `Int` in `ManagedBuffer` and `InlineArray`
- Bucket computation treats hash as `Int` via `UInt(bitPattern: hash)`

There is no semantic distinction between "a hash value" and "any integer". A caller can pass an array index, a count, or an error code where a hash value is expected. The type system provides no protection.

**Trigger**: [RES-001] Investigation — the converged Hash.Table storage-buffer layering research (v2.0.0) identified `Hash.Value` as an independent workstream. SV-1 (sentinel encoding mixes concerns) and SV-2 (typed values stored as raw integers) cannot be fully resolved without a typed hash value.

**Scope**: Per [RES-002a], this is a cross-package investigation. The type would be defined in hash-primitives (Layer 1) and consumed by hash-table-primitives (Layer 1).

## Question

Should `Hash.Protocol.hashValue` return a typed `Hash.Value` instead of raw `Int`? If so, what should `Hash.Value`'s representation, API, and normalization semantics be?

## Analysis

### Current State: Raw Int

```swift
// hash-primitives: Hash.Protocol
public var hashValue: Int {
    var hasher = Hasher()
    hash(into: &hasher)
    return hasher.finalize()   // → Int
}

// hash-table-primitives: Hash.Table
public mutating func insert(
    position: Index<Element>,
    hashValue: Int,           // ← raw Int
    equals: (Index<Element>) -> Bool
) -> Bool {
    let hash = Self.normalize(hashValue)  // ← sentinel avoidance
    ...
}

// hash-table-primitives: normalize()
public static func normalize(_ hashValue: Int) -> Int {
    let hash = hashValue == 0 ? 1 : hashValue
    return hash == Int.min ? 1 : hash
}
```

**Problems**:
1. No type safety — any `Int` is accepted where a hash value is expected
2. Normalization is the consumer's responsibility — `Hash.Table` must call `normalize()` at every entry point
3. The "forbidden values" (`0`, `Int.min`) are sentinel concerns that leak from `Hash.Table`'s storage representation into the hash value domain
4. `hashValue: Int` is indistinguishable from `arrayIndex: Int` or `byteCount: Int` at the type level

### Option A: `Hash.Value` as `Tagged<Hash, Int>`

Use the existing `Tagged` type from identity-primitives (already a dependency of hash-primitives):

```swift
extension Hash {
    public typealias Value = Tagged<Hash, Int>
}
```

**Advantages**:
- Zero-cost abstraction — `Tagged` is `@frozen`, layout-identical to `Int`
- Immediate type safety — `Hash.Value` is distinct from `Int` at compile time
- Consistent with ecosystem conventions — `Index<Element>` is `Tagged<Element, Ordinal>`, `Count` is `Tagged<Element, Cardinal>`
- No new types needed — reuses existing infrastructure
- `Sendable`, `Copyable`, `Equatable` come for free

**Disadvantages**:
- `Tagged<Hash, Int>` uses `Hash` (the namespace enum) as the tag. This is unambiguous but slightly unusual — most tags are phantom types representing the domain (e.g., `Tagged<Element, Ordinal>` where `Element` is the collection's element type)
- No built-in normalization — `Hash.Value` would store the raw output of `Hasher.finalize()`, normalization would remain separate

**API surface**:
```swift
let value: Hash.Value = element.hashValue   // typed
let raw: Int = value.rawValue               // explicit extraction
```

### Option B: `Hash.Value` as Custom Struct with Normalization

A purpose-built struct that normalizes on construction:

```swift
extension Hash {
    @frozen
    public struct Value: Sendable, Equatable {
        public let rawValue: Int

        @inlinable
        public init(_ hashValue: Int) {
            let h = hashValue == 0 ? 1 : hashValue
            self.rawValue = h == Int.min ? 1 : h
        }
    }
}
```

**Advantages**:
- Normalization happens once at construction — consumers never see sentinel-colliding values
- Eliminates `Hash.Table.normalize()` entirely — every `Hash.Value` is pre-normalized
- Stronger semantic guarantee — `Hash.Value` is always safe to store in sentinel-based hash tables

**Disadvantages**:
- Normalization is a Hash.Table concern, not a hash value concern. A hash value is the output of `Hasher.finalize()` — mapping `0 → 1` is a storage-level detail that depends on the sentinel encoding scheme. If the hash table switches to bitmap-based occupancy tracking (as Workstream 3 envisions), normalization becomes unnecessary and actively harmful (it degrades distribution by collapsing three input values to one output)
- Couples hash-primitives to hash-table-primitives' implementation strategy — a Layer 1 package should not encode another Layer 1 package's sentinel scheme
- Custom struct duplicates `Tagged`'s purpose — the ecosystem already has a zero-cost newtype mechanism
- Violates single-responsibility — `Hash.Value` should represent "a hash value", not "a hash value safe for sentinel-based open addressing"

### Option C: `Hash.Value` as `Tagged<Hash, Int>` + Separate Normalization Type

Two types: `Hash.Value` (raw, unnormalized) in hash-primitives, and a normalized variant in hash-table-primitives:

```swift
// hash-primitives
extension Hash {
    public typealias Value = Tagged<Hash, Int>
}

// hash-table-primitives (internal/package)
extension Hash.Table {
    @frozen
    struct NormalizedHash: Sendable, Equatable {
        let rawValue: Int

        @inlinable
        init(_ value: Hash.Value) {
            let h = value.rawValue == 0 ? 1 : value.rawValue
            self.rawValue = h == Int.min ? 1 : h
        }
    }
}
```

**Advantages**:
- Clean separation of concerns — `Hash.Value` is the semantic type, `NormalizedHash` is the storage-specific type
- Normalization lives where it belongs — in the hash table, not in the hash protocol
- `Hash.Value` remains pure — it wraps `Hasher.finalize()` without modification
- Migration path — when hash-table-primitives eventually eliminates sentinel encoding (Workstream 3), `NormalizedHash` is removed without affecting the `Hash.Value` API

**Disadvantages**:
- Two types for what is conceptually "a hash value" — increased cognitive load
- `NormalizedHash` may be over-engineering — `normalize()` is 2 branches; a free function or static method is simpler

### Option D: No Newtype — Keep Raw Int

Leave `hashValue` as `Int`.

**Arguments for**:
- Swift's own `Hashable.hashValue` returns `Int` — aligning with stdlib
- `Int` is universally understood — no learning curve
- Hash values are transient — computed, used for lookup, discarded. They rarely persist
- The ecosystem already mitigates type confusion via naming (`hashValue` parameter, not `value`)

**Arguments against**:
- Inconsistent with ecosystem philosophy — `Index<Element>`, `Ordinal`, `Cardinal`, `Count` all wrap raw integers for type safety. Hash values are the last remaining raw `Int` in the typed coordinate system
- Naming is not type safety — a parameter named `hashValue: Int` can still receive `array.count` without compiler error
- Prevents future enrichment — if `Hash.Value` gains additional semantics (e.g., `isNormalized` flag, truncated hash for Swiss-table control bytes), raw `Int` cannot accommodate them

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Type safety | High | Prevents misuse of non-hash integers as hash values |
| Ecosystem consistency | High | Aligns with `Index<T>`, `Ordinal`, `Cardinal` pattern |
| Separation of concerns | High | Hash values should not encode storage-level details |
| Zero-cost abstraction | High | No runtime overhead vs raw `Int` |
| Migration cost | Medium | Impact on existing consumers (`Hash.Table`, `Set.Ordered`) |
| Future extensibility | Medium | Supports Swiss-table control bytes, bitmap occupancy |
| Simplicity | Medium | Minimal cognitive overhead |

## Comparison

| Criterion | A: Tagged | B: Custom+Norm | C: Tagged+NormType | D: Raw Int |
|-----------|-----------|----------------|---------------------|------------|
| Type safety | Strong | Strong | Strong | None |
| Ecosystem consistency | Excellent | Good | Excellent | Poor |
| Separation of concerns | Good | Poor (leaks sentinels) | Excellent | N/A |
| Zero-cost | Yes | Yes | Yes | Yes |
| Migration cost | Low | Medium | Low-Medium | None |
| Future extensibility | Good | Limited | Very good | Limited |
| Simplicity | Simple | Simple | More complex | Simplest |

## Constraints

1. **hash-primitives is Layer 1** — it must not depend on hash-table-primitives or know about sentinel encoding
2. **`Tagged` is already a dependency** — identity-primitives provides `Tagged`, and hash-primitives already depends on it
3. **`Hash.Protocol.hashValue` return type change** — this is a source-breaking change for conformers that explicitly declare `hashValue`. The default implementation would change from `Int` to `Hash.Value`
4. **`Hash.Table` API change** — all `hashValue: Int` parameters become `hashValue: Hash.Value`. Callers that pass `element.hashValue` work unchanged (type flows through). Callers that pass literal integers (tests) need `Hash.Value(rawValue: 42)`
5. **No Foundation** — [PRIM-FOUND-001] applies

## Prior Art

| System | Hash Value Type | Notes |
|--------|----------------|-------|
| Swift stdlib | `Int` | `Hashable.hashValue: Int` |
| Rust `std::hash` | `u64` | `Hasher::finish() -> u64`, untyped |
| Java | `int` | `Object.hashCode() -> int`, untyped |
| C++ `std::hash` | `size_t` | `operator() -> size_t`, untyped |
| Haskell `Hashable` | `Int` | `hash :: a -> Int`, untyped |

No mainstream language wraps hash values in a newtype. However, the Swift Institute ecosystem already wraps indices (`Index<T>`), ordinals (`Ordinal`), cardinals (`Cardinal`), counts (`Count`), and offsets (`Offset`). Wrapping hash values is the logical extension of this philosophy.

## Recommendation

**Option A: `Hash.Value` as `Tagged<Hash, Int>`**.

Rationale:

1. **Consistency is the strongest argument**. The ecosystem wraps every other integer domain — indices, ordinals, cardinals, counts, offsets. Hash values are the remaining hole. `Tagged<Hash, Int>` fills it with zero new infrastructure.

2. **Separation of concerns eliminates Option B**. Normalization is a Hash.Table storage concern. Baking it into `Hash.Value` couples hash-primitives to a specific storage strategy. When hash-table-primitives eventually moves to bitmap-based occupancy (Workstream 3), normalization becomes unnecessary. The hash value type should not encode this.

3. **Option C over-engineers the normalization layer**. The current `normalize()` is a 2-branch function. Promoting it to a dedicated type (`NormalizedHash`) adds a type for something that is better expressed as a static method. If normalization becomes more complex (e.g., Swiss-table H1/H2 splitting), a dedicated type may be warranted — but that decision belongs to Workstream 3, not here.

4. **Option D is inconsistent with ecosystem principles**. The typed coordinate system is a core design decision. Leaving hash values as the sole untyped integer would be a gap.

### Implementation Sketch

**hash-primitives changes**:

```swift
// Hash.swift — add to namespace
extension Hash {
    /// A hash value produced by `Hash.Protocol.hashValue`.
    ///
    /// Wraps the raw `Int` output of `Hasher.finalize()` in a typed wrapper
    /// to prevent accidental misuse of non-hash integers as hash values.
    public typealias Value = Tagged<Hash, Int>
}

// Hash.Protocol.swift — change return type
extension Hash.`Protocol` where Self: ~Copyable {
    @inlinable
    public var hashValue: Hash.Value {
        var hasher = Hasher()
        hash(into: &hasher)
        return Hash.Value(rawValue: hasher.finalize())
    }
}
```

**hash-table-primitives changes**:

```swift
// All public API: hashValue: Int → hashValue: Hash.Value
public mutating func insert(
    position: Index<Element>,
    hashValue: Hash.Value,              // was: Int
    equals: (Index<Element>) -> Bool
) -> Bool

// Internal: normalize accepts Hash.Value
public static func normalize(_ hashValue: Hash.Value) -> Int {
    let h = hashValue.rawValue
    let hash = h == 0 ? 1 : h
    return hash == Int.min ? 1 : hash
}
```

### Migration Impact

| Consumer | Change Required |
|----------|----------------|
| `Hash.Table` | `hashValue: Int` → `hashValue: Hash.Value` in all public methods |
| `Hash.Table.normalize()` | Accept `Hash.Value`, extract `.rawValue` internally |
| `Set.Ordered` | Passes `element.hashValue` — type flows through, no change |
| Tests | `hashValue: 42` → `hashValue: Hash.Value(rawValue: 42)` |

## Outcome

**Status**: DECISION

**Decision**: Option A — `Hash.Value = Tagged<Hash, Int>`. Implemented in hash-primitives and hash-table-primitives.

### Open Questions

1. **Should `Hash.Value` conform to `Hash.Protocol`?** A hash value can itself be hashed (it's just an `Int`). This would enable `Hash.Value` to participate in compound hashing. `Tagged` already conforms when `RawValue: Hash.Protocol`, so this may come for free.

2. **Should `Hash.Value` provide arithmetic?** Hash values are not numbers — arithmetic on them is meaningless. `Tagged<Hash, Int>` inherits no arithmetic from `Int` unless explicitly provided. This is correct: `hashA + hashB` has no semantic meaning.

3. **Should `Hash.Protocol.hashValue` be deprecated in favor of a method?** Swift's `Hashable` provides both `hashValue` (property) and `hash(into:)` (method). The property is essentially deprecated in stdlib usage. Should `Hash.Protocol` follow the same path and only provide `hash(into:)`? This is orthogonal to the `Hash.Value` newtype question.

4. **Naming: `Hash.Value` vs `Hash.Code`?** Java uses "hashCode", Rust/Swift use "hash value". `Hash.Value` aligns with Swift convention (`hashValue` property → `Hash.Value` type). `Hash.Code` would be a departure.

## References

- Hash.Table storage-buffer layering research: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Research/hash-table-storage-buffer-layering.md` (v2.0.0)
- Hash.Protocol: `/Users/coen/Developer/swift-primitives/swift-hash-primitives/Sources/Hash Primitives Core/Hash.Protocol.swift`
- Hash.Table.normalize: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift:225`
- Tagged type: identity-primitives (dependency of hash-primitives)
- Swift Hashable documentation: `https://developer.apple.com/documentation/swift/hashable`
