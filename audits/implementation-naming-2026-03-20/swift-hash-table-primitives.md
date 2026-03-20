# swift-hash-table-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation [IMPL-*], naming [API-NAME-*]
**Scope**: All 31 `.swift` files across `Hash Table Primitives Core` and `Hash Table Primitives`
**Mode**: READ-ONLY

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|----------|-------------|
| HT-001 | HIGH | [API-IMPL-005] | Hash.Table.swift | 63-305 | 8 types declared in one file |
| HT-002 | HIGH | [IMPL-010] | Hash.Table.swift | 280, 286, 295, 303 | `Int(bitPattern:)` at InlineArray access call sites |
| HT-003 | HIGH | [IMPL-002] [PATTERN-021] | Hash.Table.swift | 295-297 | Double `__unchecked` chain to construct `Index<Element>.Bounded` |
| HT-004 | HIGH | [IMPL-002] [PATTERN-017] | Hash.Table+BufferAccess.swift | 31, 34 | `.rawValue` and `__unchecked` at subscript boundary |
| HT-005 | HIGH | [IMPL-052] | Hash.Table (heap) | all Lookup/Insertion/Removal/ForEach/PositionUpdates | Heap `Hash.Table` uses unbounded `Index<Element>` everywhere; no bounded index flow |
| HT-006 | MEDIUM | [PATTERN-021] | Hash.Occupied.View.Iterator.swift | 73-75 | `__unchecked` + `UInt(bitPattern:)` chain in iterator `next()` |
| HT-007 | MEDIUM | [PATTERN-021] | Hash.Occupied.Static.Iterator.swift | 73-75 | Same `__unchecked` chain in Static iterator `next()` |
| HT-008 | MEDIUM | [IMPL-010] | Hash.Table+Lookup.swift | 29-31, 77-79, 118-120 | `UInt(bitPattern:)` + `.rawValue` for bucket computation repeated 3 times |
| HT-009 | MEDIUM | [IMPL-010] | Hash.Table+Bucket.swift | 26 | `UInt(bitPattern:)` + `.rawValue` + `__unchecked` in `bucket(for:)` static |
| HT-010 | MEDIUM | [IMPL-010] | Hash.Table.swift | 133 | `Int(bitPattern: minimumCapacity)` in `bucketCapacity(for:)` |
| HT-011 | MEDIUM | [IMPL-010] | Hash.Table.swift | 247 | `UInt(bitPattern: hash)` in `bucket(for:)` instance |
| HT-012 | MEDIUM | [API-NAME-002] | Core: Static+PositionUpdates.swift | 19, 34, 48 | Compound method names: `decrementAllPositions`, `updatePositionInternal` |
| HT-013 | MEDIUM | [API-NAME-002] | Core: Static+Removal.swift | 62 | Compound method name: `clearAll` |
| HT-014 | MEDIUM | [API-NAME-002] | Core: Static+ForEach.swift | 20, 40, 59 | Compound method names: `eachOccupied`, `eachPosition`, `eachOccupiedWhile` |
| HT-015 | LOW | [IMPL-033] | Hash.Table+ForEach.swift | 40-50 | Manual `while` loop in Property.View forEach |
| HT-016 | LOW | [IMPL-033] | Hash.Table+PositionUpdates.swift | 45-56 | Manual `while` loop in Property.View decrement |
| HT-017 | LOW | [IMPL-002] | Hash.Table.swift | 150 | `hashValue.rawValue` in `normalize()` |
| HT-018 | LOW | [IMPL-010] | Hash.Table+Insertion.swift | 148 | `Int(bitPattern: position)` in `grow()` |
| HT-019 | LOW | [IMPL-010] | Core: Static+Removal.swift | 80 | `Int(bitPattern: _count)` in `rehash()` |
| HT-020 | INFO | [IMPL-020] | Hash.Table+Bucket.swift | whole file | Good: `bucket.for(hash:)` / `bucket.next()` Property.View pattern |
| HT-021 | INFO | [IMPL-050] | Core: Static+Lookup/Insertion/Removal | whole files | Good: Static type consistently uses `Index<Element>.Bounded<bucketCapacity>` |
| HT-022 | INFO | [API-NAME-001] | All | whole package | Good: All types follow `Nest.Name` pattern (`Hash.Table`, `Hash.Occupied`, etc.) |

---

## Findings

### HT-001 [HIGH] [API-IMPL-005] Multiple types in Hash.Table.swift

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Lines**: 63-305

This single file declares 8 types:
1. `Hash.Table<Element>` (line 63)
2. `Hash.Table.Bucket` (line 68)
3. `Hash.Table.Bucket.Index` (typealias, line 70)
4. `Hash.Table.Bucket.Ops` (line 73)
5. `Hash.Table.ForEach` (line 77)
6. `Hash.Table.Remove` (line 80)
7. `Hash.Table.Positions` (line 83)
8. `Hash.Table.Static<bucketCapacity>` (line 184)

[API-IMPL-005] requires one type per file. The tag enums (`ForEach`, `Remove`, `Positions`, `Ops`) and `Bucket` marker type should each be in separate files. `Hash.Table.Static` is documented with a justification comment (line 181-183: nested value-generic types lose parent type context in extensions), which makes it a candidate for [PATTERN-016] conscious technical debt, but the tag enums have no such constraint.

---

### HT-002 [HIGH] [IMPL-010] Int(bitPattern:) at InlineArray access call sites

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Lines**: 280, 286, 295, 303

The `readHash`, `writeHash`, `readPosition`, and `writePosition` methods on `Hash.Table.Static` convert `Bucket.Index` to `Int` at every access:

```swift
// Line 280
_hashes[Int(bitPattern: bucket.position)]

// Line 295
let ordinal = Ordinal(UInt(bitPattern: _positions[Int(bitPattern: bucket.position)]))

// Line 303
_positions[Int(bitPattern: bucket.position)] = Int(bitPattern: value.rawValue.ordinal)
```

Per [IMPL-010], `Int(bitPattern:)` should live in boundary overloads (e.g., an `InlineArray` subscript accepting `Bucket.Index`), not at every call site. The `bucket.position` -> `Int` conversion is repeated 6 times across these 4 methods.

---

### HT-003 [HIGH] [IMPL-002] [PATTERN-021] Double __unchecked chain in readPosition

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Lines**: 294-297

```swift
func readPosition(at bucket: Bucket.Index) -> Index<Element>.Bounded<bucketCapacity> {
    let ordinal = Ordinal(UInt(bitPattern: _positions[Int(bitPattern: bucket.position)]))
    let finite: Ordinal.Finite<bucketCapacity> = .init(__unchecked: (), ordinal)
    return .init(__unchecked: (), finite)
}
```

This constructs a bounded index through a 3-step chain: raw Int -> Ordinal -> Finite (unchecked) -> Bounded (unchecked). Per [IMPL-002], typed arithmetic should eliminate raw-value chains. Per [PATTERN-021], when a typed construction path exists (e.g., `Index<Element>.Bounded<N>` narrowing from the stored value), it should be used over `__unchecked`.

Similarly, `writePosition` (line 303) decomposes in the opposite direction: `value.rawValue.ordinal` -> `Int(bitPattern:)`.

---

### HT-004 [HIGH] [IMPL-002] [PATTERN-017] .rawValue at subscript boundary

**File**: `Sources/Hash Table Primitives Core/Hash.Table+BufferAccess.swift`
**Lines**: 31, 34

The heap `Hash.Table` position subscript getter/setter:

```swift
get {
    let raw = _buffer[payload: bucket.retag(Int.self)]
    return Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
}
set {
    _buffer[payload: bucket.retag(Int.self)] = Int(bitPattern: newValue.position.rawValue)
}
```

The setter accesses `.position.rawValue` (two levels of raw extraction). This is a subscript (boundary code), so some mechanism is expected, but `.position.rawValue` is deeper than necessary. A single `Int(bitPattern: newValue)` boundary overload on `Index<Element>` would confine the extraction.

---

### HT-005 [HIGH] [IMPL-052] Heap Hash.Table lacks bounded index flow

**Files**: All `Hash Table Primitives/Hash.Table+*.swift` files

The heap `Hash.Table` does not have a compile-time capacity, so `Index<Element>.Bounded<N>` is structurally impossible. However, the current API uses entirely unbounded `Index<Element>` with no capacity relationship at all. This means consumers who transition from `Hash.Table.Static<N>` (which has full bounded flow) to heap `Hash.Table` lose all compile-time position safety.

This is a structural design observation rather than a remediable violation -- the heap table has dynamic capacity. However, per [IMPL-052], the bounded variants are the "sole public API" for static-capacity types, and there is no bounded-to-unbounded bridging API. Consumers switching between static and heap hash tables must manually widen all positions.

---

### HT-006 [MEDIUM] [PATTERN-021] __unchecked chain in View.Iterator.next()

**File**: `Sources/Hash Table Primitives Core/Hash.Occupied.View.Iterator.swift`
**Lines**: 73-75

```swift
let position = Index<Source>(
    __unchecked: (), Ordinal(UInt(bitPattern: unsafe _positions[bucket]))
)
```

The `__unchecked` construction is inside an iterator (infrastructure code), but the chain `Int -> UInt(bitPattern:) -> Ordinal -> Index(__unchecked:)` is the same mechanistic pattern as HT-003. A typed conversion path from the stored `Int` representation to `Index<Source>` would eliminate this.

---

### HT-007 [MEDIUM] [PATTERN-021] Same __unchecked chain in Static.Iterator.next()

**File**: `Sources/Hash Table Primitives Core/Hash.Occupied.Static.Iterator.swift`
**Lines**: 73-75

Identical pattern to HT-006 but in the InlineArray-based iterator. Same chain: `Int -> UInt(bitPattern:) -> Ordinal -> Index(__unchecked:)`.

---

### HT-008 [MEDIUM] [IMPL-010] Repeated bucket computation in Hash.Table+Lookup.swift

**File**: `Sources/Hash Table Primitives/Hash.Table+Lookup.swift`
**Lines**: 29-31, 77-79, 118-120

The bucket-from-hash computation is inlined 3 times:

```swift
var currentBucket = Bucket.Index(
    __unchecked: (),
    Ordinal(UInt(bitPattern: hash)) % capacity.rawValue
)
```

The `Hash.Table.Static` equivalent uses `bucket(for:)` (and the Property.View version uses `bucket.for(hash:)`). The heap `Hash.Table` has a static `bucket(for:capacity:)` in `Hash.Table+Bucket.swift` (line 22-27) but the Lookup file does not call it -- it manually inlines the same computation with `__unchecked` + `.rawValue`.

Per [IMPL-010] and [PATTERN-017], this mechanism should be confined to the `bucket(for:capacity:)` static method, and all three lookup methods should delegate to it.

---

### HT-009 [MEDIUM] [IMPL-010] Mechanism in bucket(for:capacity:) static

**File**: `Sources/Hash Table Primitives/Hash.Table+Bucket.swift`
**Line**: 26

```swift
Bucket.Index(__unchecked: (), Ordinal(UInt(bitPattern: hash)) % capacity.rawValue)
```

This is the designated bucket computation boundary. The `capacity.rawValue` access is mechanism -- per [IMPL-003a], the modular arithmetic should operate on typed values. However, since this IS the boundary method, the violation is contained. The real problem is HT-008 (callers not using this boundary).

---

### HT-010 [MEDIUM] [IMPL-010] Int(bitPattern:) in bucketCapacity(for:)

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Line**: 133

```swift
let minCap = Int(bitPattern: minimumCapacity)
```

The entire `bucketCapacity(for:)` method drops into raw `Int` arithmetic (lines 133-141) and then wraps back into typed values at line 141. This is a single boundary method, but the `Int` computation spans 8 lines of raw arithmetic. Typed arithmetic on `Index<Element>.Count` and `Index<Bucket>.Count` would express this as intent.

---

### HT-011 [MEDIUM] [IMPL-010] UInt(bitPattern:) in Static bucket(for:)

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Line**: 247

```swift
let bucketOrd = Ordinal(UInt(bitPattern: hash)) % Cardinal(UInt(bucketCapacity))
```

This is the Static variant's bucket boundary. Same pattern as HT-009 but with explicit `Cardinal(UInt(...))` wrapping. Again, this is boundary code, but the `UInt(bitPattern:)` could be pushed into a typed overload on `Hash.Value`.

---

### HT-012 [MEDIUM] [API-NAME-002] Compound method names in Core Static+PositionUpdates

**File**: `Sources/Hash Table Primitives Core/Hash.Table.Static+PositionUpdates.swift`
**Lines**: 19, 34, 48

```swift
package mutating func decrementAllPositions(after:)    // line 19
package mutating func updatePositionInternal(forHash:)  // line 34
package mutating func updatePositionInternal(atBucket:) // line 48
```

These are `package`-scoped (internal delegation targets), so per [IMPL-024] compound names in the static/implementation layer are allowed. However, these are not static methods -- they are instance methods on the type itself, called from Property.View extensions. The naming rule relaxation in [IMPL-024] is specifically for "Static methods (the implementation layer)." Instance methods with `package` access still form part of the API surface within the package.

Severity reduced because these are not public API.

---

### HT-013 [MEDIUM] [API-NAME-002] Compound method name: clearAll

**File**: `Sources/Hash Table Primitives Core/Hash.Table.Static+Removal.swift`
**Line**: 62

```swift
package mutating func clearAll()
```

Same analysis as HT-012. This is a package-internal delegation target for `remove.all()`. Compound name in implementation layer.

---

### HT-014 [MEDIUM] [API-NAME-002] Compound method names in Core Static+ForEach

**File**: `Sources/Hash Table Primitives Core/Hash.Table.Static+ForEach.swift`
**Lines**: 20, 40, 59

```swift
package borrowing func eachOccupied(_:)       // line 20
package borrowing func eachPosition(_:)       // line 40
package borrowing func eachOccupiedWhile(_:)  // line 59
```

Same analysis as HT-012. These are package-internal delegation targets for the Property.View `forEach.occupied {}` and `forEach.position {}` APIs. The compound names are in the implementation layer.

---

### HT-015 [LOW] [IMPL-033] Manual while loop in Property.View forEach

**File**: `Sources/Hash Table Primitives/Hash.Table+ForEach.swift`
**Lines**: 40-50

```swift
public func occupied(_ body: ...) {
    var bucket: Hash.Table<Element>.Bucket.Index = .zero
    let cap = unsafe base.pointee.bucketCapacity
    while bucket < cap {
        ...
        bucket += .one
    }
}
```

Per [IMPL-033], iteration should use the highest-level abstraction. The heap `Hash.Table`'s Property.View forEach uses a manual `while` loop. This is typed mechanism (Bucket.Index, .one increment), but it's still mechanism. The `Hash.Table.Static` equivalent delegates to `eachOccupied()` which also uses a manual loop internally (via `forEachBucket`), but at least the delegation is clean.

The heap `Hash.Table` forEach could delegate to a similar internal method rather than inlining the loop in the Property.View extension.

---

### HT-016 [LOW] [IMPL-033] Manual while loop in Property.View decrement

**File**: `Sources/Hash Table Primitives/Hash.Table+PositionUpdates.swift`
**Lines**: 45-56

Same pattern as HT-015. The `positions.decrement(after:)` Property.View method manually loops through buckets instead of delegating to an internal method.

---

### HT-017 [LOW] [IMPL-002] .rawValue in normalize()

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Line**: 150

```swift
let raw = hashValue.rawValue
```

The `normalize()` method extracts `.rawValue` from `Hash.Value` to do sentinel comparison. This is a boundary method that converts between the typed hash value domain and the raw storage domain. The `.rawValue` access is justified here since `normalize()` IS the boundary. LOW severity.

---

### HT-018 [LOW] [IMPL-010] Int(bitPattern: position) in grow()

**File**: `Sources/Hash Table Primitives/Hash.Table+Insertion.swift`
**Line**: 148

```swift
newBuffer[payload: targetBucket.retag(Int.self)] = Int(bitPattern: position)
```

Inside `grow()`, which is a bulk internal operation. The `Int(bitPattern:)` is the boundary between typed `Index<Element>` and the raw `Buffer.Slots` storage. This is boundary code, but a typed `Buffer.Slots` subscript accepting `Index<Element>` would push the conversion down.

---

### HT-019 [LOW] [IMPL-010] Int(bitPattern: _count) in rehash()

**File**: `Sources/Hash Table Primitives Core/Hash.Table.Static+Removal.swift`
**Line**: 80

```swift
entries.reserveCapacity(Int(bitPattern: _count))
```

Converting typed count to `Int` for `Array.reserveCapacity`. This is a stdlib boundary -- `reserveCapacity` only accepts `Int`. A typed overload on `Array` would absorb this, but it's a single occurrence in a bulk operation. LOW severity.

---

### HT-020 [INFO] Good: Property.View bucket operations

**File**: `Sources/Hash Table Primitives/Hash.Table+Bucket.swift`

The `bucket.for(hash:)` and `bucket.next()` Property.View pattern is well-implemented per [IMPL-020]. The heap `Hash.Table` exposes bucket operations through nested accessors (`table.bucket.for(hash:)`, `table.bucket.next(current)`), which reads as intent.

---

### HT-021 [INFO] Good: Static type uses bounded indices consistently

**Files**: All Core `Hash.Table.Static+*.swift` files

The `Hash.Table.Static<bucketCapacity>` type consistently uses `Index<Element>.Bounded<bucketCapacity>` in its public API: `position(forHash:equals:)` returns `Bounded`, `insert(position:)` accepts `Bounded`, `remove()` returns `Bounded`, `forEach.position {}` yields `Bounded`, `positions.decrement(after:)` accepts `Bounded`. This is excellent compliance with [IMPL-050] and [IMPL-052].

---

### HT-022 [INFO] Good: All types follow Nest.Name pattern

All types use proper nested namespacing per [API-NAME-001]:
- `Hash.Table<Element>`
- `Hash.Table.Bucket`
- `Hash.Table.Static<bucketCapacity>`
- `Hash.Occupied<Source>`
- `Hash.Occupied.View`
- `Hash.Occupied.View.Iterator`
- `Hash.Occupied.Static<bucketCapacity>`
- `Hash.Occupied.Static.Iterator`

No compound type names found.

---

## Statistics

| Category | Count |
|----------|-------|
| Total findings | 22 |
| HIGH | 5 |
| MEDIUM | 7 |
| LOW | 5 |
| INFO (positive) | 3 |
| `Int(bitPattern:)` usages | 18 (6 in boundary code, 12 at call sites) |
| `__unchecked` constructions | 12 (2 in API parameters, 10 in implementations) |
| `.rawValue` accesses | 7 (4 in boundary code, 3 at non-boundary sites) |

## Remediation Priority

1. **HT-008** (HIGH impact, easy fix): Lookup methods should call `bucket(for:capacity:)` static instead of inlining the computation. Eliminates 3 `__unchecked` + `.rawValue` sites.
2. **HT-002** (HIGH impact, medium effort): Add `InlineArray` subscript overload accepting `Bucket.Index`. Eliminates 6 `Int(bitPattern:)` sites.
3. **HT-003** (HIGH impact, medium effort): Add a typed construction path from raw `Int` storage to `Index<Element>.Bounded<N>`. Eliminates the double-`__unchecked` chain.
4. **HT-001** (HIGH, structural): Extract tag enums to separate files per [API-IMPL-005].
5. **HT-004** (HIGH, medium effort): Add `Int(bitPattern:)` boundary overload on `Index<Element>` for buffer storage.
