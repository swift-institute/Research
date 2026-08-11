# API Surface Catalog: swift-hash-table-primitives

Complete catalog of every `public` and `package` declaration across all source modules.

Generated: 2026-04-02

---

## Module: Hash Table Primitives

Re-export umbrella module. No new types or API surface.

### `Sources/Hash Table Primitives/exports.swift`

```swift
// Line 12: @_exported public import Hash_Table_Primitives_Core
// Line 13: @_exported public import Hash_Table_Accessor_Primitives
```

---

## Module: Hash Table Primitives Core

### `Sources/Hash Table Primitives Core/exports.swift`

Re-exports only (no new types):

```swift
// Line 12: @_exported public import Hash_Primitives
// Line 13: @_exported public import Index_Primitives
// Line 14: @_exported public import Cyclic_Index_Primitives
// Line 15: @_exported public import Buffer_Slots_Primitives
```

---

### `Sources/Hash Table Primitives Core/Hash.Table.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 63 | `public` | `struct Table<Element: ~Copyable>: ~Copyable` (nested in `Hash`) |
| 140 | | `extension Hash.Table: Copyable where Element: Copyable` |
| 141 | | `extension Hash.Table: @unchecked Sendable where Element: Sendable` |

#### Stored Properties (package)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 68 | `package` | `var _count: Index<Element>.Count` |
| 71 | `package` | `var _occupied: Index<Bucket>.Count` |
| 74 | `package` | `var _buffer: Buffer<Int>.Slots<Int>` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 80 | `public` | `static var empty: Int` |
| 84 | `public` | `static var deleted: Int` |
| 93 | `public` | `init(minimumCapacity: Index<Element>.Count = .zero)` |
| 112 | `public` | `static func bucketCapacity(for minimumCapacity: Index<Element>.Count) -> Index<Bucket>.Count` |
| 129 | `public` | `static func normalize(_ hashValue: Hash.Value) -> Int` |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Bucket.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 14 | `public` | `struct Bucket: ~Copyable` (nested in `Hash.Table` where `Element: ~Copyable`) |
| 16 | `public` | `typealias Index = Index_Primitives.Index<Bucket>` |
| 19 | `public` | `enum Ops` (nested in `Bucket`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Positions.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 14 | `public` | `enum Positions` (nested in `Hash.Table` where `Element: ~Copyable`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.ForEach.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 14 | `public` | `enum ForEach` (nested in `Hash.Table` where `Element: ~Copyable`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Remove.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 14 | `public` | `enum Remove` (nested in `Hash.Table` where `Element: ~Copyable`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table+BufferAccess.swift`

All accessors are `package` visibility.

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 15 | `package` | `var bucketCapacity: Index<Bucket>.Count` (computed property) |
| 21 | `package` | `subscript(hash bucket: Bucket.Index) -> Int` (get/set) |
| 28 | `package` | `subscript(position bucket: Bucket.Index) -> Index<Element>` (get/set) |

---

### `Sources/Hash Table Primitives Core/Hash.Table+occupied.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 25 | `public` | `var occupied: Hash.Occupied<Element>.View` (computed, where `Element: Copyable`) |

---

### `Sources/Hash Table Primitives Core/Hash.Occupied.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 19 | `public` | `struct Occupied<Source: ~Copyable>: Copyable, Sendable` (nested in `Hash`) |

#### Public Properties

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 21 | `public` | `let bucket: Hash.Table<Source>.Bucket.Index` |
| 24 | `public` | `let hash: Int` |
| 27 | `public` | `let position: Index<Source>` |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 30 | `package` | `init(bucket: Hash.Table<Source>.Bucket.Index, hash: Int, position: Index<Source>)` |

---

### `Sources/Hash Table Primitives Core/Hash.Occupied.Static.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 18 | `public` | `struct Static<let bucketCapacity: Int>: Copyable, Sendable` (nested in `Hash.Occupied` where `Source: Copyable`) |

#### Package Properties

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 27 | `package` | `let _count: Index<Source>.Count` |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 29 | `package` | `init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>, count: Index<Source>.Count)` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 36 | `public` | `func makeIterator() -> Iterator` |

---

### `Sources/Hash Table Primitives Core/Hash.Occupied.Static.Iterator.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 20 | `public` | `struct Iterator: Sequence.Iterator.Protocol, IteratorProtocol` (nested in `Hash.Occupied.Static`) |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 37 | `package` | `init(hashes: InlineArray<bucketCapacity, Int>, positions: InlineArray<bucketCapacity, Int>)` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 46 | `public` | `mutating func nextSpan(maximumCount: Cardinal) -> Span<Hash.Occupied<Source>>` |
| 66 | `public` | `mutating func next() -> Hash.Occupied<Source>?` |

---

### `Sources/Hash Table Primitives Core/Hash.Occupied.View.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 17 | `public` | `@unsafe struct View: Copyable, @unchecked Sendable` (nested in `Hash.Occupied` where `Source: Copyable`) |

#### Package Properties

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 28 | `package` | `let _count: Index<Source>.Count` |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 31 | `package` | `init(hashes: UnsafePointer<Int>, positions: UnsafePointer<Int>, capacity: Hash.Table<Source>.Bucket.Index.Count, count: Index<Source>.Count)` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 39 | `public` | `func makeIterator() -> Iterator` |

---

### `Sources/Hash Table Primitives Core/Hash.Occupied.View.Iterator.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 20 | `public` | `@unsafe struct Iterator: Sequence.Iterator.Protocol, IteratorProtocol` (nested in `Hash.Occupied.View`) |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 37 | `package` | `init(hashes: UnsafePointer<Int>, positions: UnsafePointer<Int>, capacity: Hash.Table<Source>.Bucket.Index.Count)` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 46 | `public` | `mutating func nextSpan(maximumCount: Cardinal) -> Span<Hash.Occupied<Source>>` |
| 66 | `public` | `mutating func next() -> Hash.Occupied<Source>?` |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 37 | `public` | `struct Static<let bucketCapacity: Int>: ~Copyable` (nested in `Hash.Table` where `Element: ~Copyable`) |
| 41 | `public` | `typealias Bucket = Hash.Table<Element>.Bucket` |
| 163 | | `extension Hash.Table.Static: Copyable where Element: Copyable` |
| 164 | | `extension Hash.Table.Static: @unchecked Sendable where Element: Sendable` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 47 | `public` | `static var empty: Int` |
| 51 | `public` | `static var deleted: Int` |
| 55 | `public` | `static func normalize(_ hashValue: Hash.Value) -> Int` |
| 81 | `public` | `init()` |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 99 | `package` | `func bucket(for hash: Int) -> Bucket.Index` |
| 108 | `package` | `func bucket(after current: Bucket.Index) -> Bucket.Index` |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+Properties.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 15 | `public` | `var count: Index<Element>.Count` (computed) |
| 19 | `public` | `var isEmpty: Bool` (computed) |
| 23 | `public` | `var occupancy: Bucket.Index.Count` (computed) |
| 27 | `public` | `var capacity: Bucket.Index.Count` (computed) |
| 37 | `public` | `var shouldGrow: Bool` (computed) |
| 47 | `public` | `var isFull: Bool` (computed) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+Insertion.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 28 | `public` | `mutating func insert(position: Index<Element>.Bounded<bucketCapacity>, hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Bool` |
| 103 | `public` | `mutating func insert<Context: ~Copyable>(position: Index<Element>.Bounded<bucketCapacity>, hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool) -> Bool` |
| 169 | `public` | `mutating func insert(__unchecked: Void, position: Index<Element>.Bounded<bucketCapacity>, hashValue: Hash.Value) -> Bool` |

All three are `@discardableResult`.

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+Lookup.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 26 | `public` | `borrowing func position(forHash hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Index<Element>.Bounded<bucketCapacity>?` |
| 71 | `public` | `borrowing func position<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool) -> Index<Element>.Bounded<bucketCapacity>?` |
| 109 | `public` | `borrowing func index(forHash hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Bucket.Index?` |
| 151 | `public` | `borrowing func index<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool) -> Bucket.Index?` |
| 191 | `public` | `borrowing func contains<Context: ~Copyable>(hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool) -> Bool` |
| 207 | `public` | `borrowing func contains(hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Bool` |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+Removal.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 26 | `public` | `mutating func remove(hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Index<Element>.Bounded<bucketCapacity>?` (`@discardableResult`) |
| 57 | `public` | `mutating func remove<Context: ~Copyable>(hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool) -> Index<Element>.Bounded<bucketCapacity>?` (`@discardableResult`) |
| 97 | `public` | `mutating func remove(atBucket bucket: Bucket.Index) -> Index<Element>.Bounded<bucketCapacity>` (`@discardableResult`) |
| 125 | `public` | `mutating func rehash()` |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 110 | `package` | `mutating func clearAll()` |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+occupied.swift`

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 25 | `public` | `var occupied: Hash.Occupied<Element>.Static<bucketCapacity>` (computed, where `Element: Copyable`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+ForEach.swift`

All methods are `package` visibility.

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 20 | `package` | `borrowing func eachOccupied(_ body: (_ bucket: Bucket.Index, _ position: Index<Element>.Bounded<bucketCapacity>) -> Void)` |
| 40 | `package` | `borrowing func eachPosition(_ body: (Index<Element>.Bounded<bucketCapacity>) -> Void)` |
| 59 | `package` | `borrowing func eachOccupiedWhile(_ body: (_ bucket: Bucket.Index, _ hash: Int, _ position: Index<Element>.Bounded<bucketCapacity>) -> Bool) -> Bool` (`@discardableResult`) |

---

### `Sources/Hash Table Primitives Core/Hash.Table.Static+PositionUpdates.swift`

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 19 | `package` | `mutating func decrementAllPositions(after removedPosition: Index<Element>.Bounded<bucketCapacity>)` |
| 34 | `package` | `mutating func updatePositionInternal(forHash hashValue: Hash.Value, equals: (Index<Element>.Bounded<bucketCapacity>) -> Bool, newPosition: Index<Element>.Bounded<bucketCapacity>) -> Bool` (`@discardableResult`) |
| 50 | `public` | `mutating func updatePositionInternal<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<bucketCapacity>, borrowing Context) -> Bool, newPosition: Index<Element>.Bounded<bucketCapacity>) -> Bool` (`@discardableResult`) |
| 65 | `package` | `mutating func updatePositionInternal(atBucket bucket: Bucket.Index, newPosition: Index<Element>.Bounded<bucketCapacity>)` |

---

## Module: Hash Table Accessor Primitives

### `Sources/Hash Table Accessor Primitives/exports.swift`

Re-exports:

```swift
// Line 12: @_exported public import Hash_Table_Primitives_Core
// Line 13: @_exported public import Property_Primitives
// Line 14: @_exported public import Sequence_Primitives
```

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+Properties.swift`

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 17 | `public` | `var count: Index<Element>.Count` (computed) |
| 23 | `public` | `var isEmpty: Bool` (computed) |
| 29 | `public` | `var capacity: Index<Bucket>.Count` (computed) |

#### Internal (not public/package)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 35 | internal | `var shouldGrow: Bool` (computed) |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+Insertion.swift`

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 26 | `public` | `mutating func insert(position: Index<Element>, hashValue: Hash.Value, equals: (Index<Element>) -> Bool) -> Bool` (`@discardableResult`) |
| 96 | `public` | `mutating func insert<Context: ~Copyable>(position: Index<Element>, hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>, borrowing Context) -> Bool) -> Bool` (`@discardableResult`) |
| 157 | `public` | `mutating func insert(__unchecked: Void, position: Index<Element>, hashValue: Hash.Value)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+Lookup.swift`

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 23 | `public` | `borrowing func position(forHash hashValue: Hash.Value, equals: (Index<Element>) -> Bool) -> Index<Element>?` |
| 70 | `public` | `borrowing func position<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>, borrowing Context) -> Bool) -> Index<Element>?` |
| 112 | `public` | `borrowing func index(forHash hashValue: Hash.Value, equals: (Index<Element>) -> Bool) -> Bucket.Index?` |
| 158 | `public` | `borrowing func index<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>, borrowing Context) -> Bool) -> Bucket.Index?` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+Removal.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.Remove, Hash.Table<Element>>.View.Typed<Element>` (on `Hash.Table.Remove`) |

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 30 | `public` | `mutating func remove(hashValue: Hash.Value, equals: (Index<Element>) -> Bool) -> Index<Element>?` (`@discardableResult`) |
| 58 | `public` | `mutating func remove<Context: ~Copyable>(hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>, borrowing Context) -> Bool) -> Index<Element>?` (`@discardableResult`) |
| 98 | `public` | `mutating func remove(at bucketIdx: Bucket.Index)` |
| 109 | `public` | `var remove: Remove.View` (computed, `_read`/`_modify`) |

#### Public API (on `Property.View.Typed` where `Tag == Remove, Base == Hash.Table`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 124 | `public` | `mutating func all(keepingCapacity: Bool = false)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+ForEach.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `typealias View = Property<Hash.Table<Element>.ForEach, Hash.Table<Element>>.View.Typed<Element>` (on `Hash.Table.ForEach`) |

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 24 | `public` | `var forEach: ForEach.View` (computed, `_read`) |

#### Public API (on `Property.View.Typed` where `Tag == ForEach, Base == Hash.Table`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 39 | `public` | `func occupied(_ body: (Hash.Table<Element>.Bucket.Index, Index<Element>) -> Void)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+PositionUpdates.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.Positions, Hash.Table<Element>>.View.Typed<Element>` (on `Hash.Table.Positions`) |

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 23 | `public` | `var positions: Positions.View` (computed, `_read`/`_modify`) |

#### Public API (on `Property.View.Typed` where `Tag == Positions, Base == Hash.Table`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 43 | `public` | `mutating func decrement(after removedPosition: Index<Element>)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+ensureUnique.swift`

#### Public API (on `Hash.Table` where `Element: Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 27 | `public` | `mutating func ensureUnique() -> Bool` (`@discardableResult`) |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table+Bucket.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `typealias View = Property<Hash.Table<Element>.Bucket.Ops, Hash.Table<Element>>.View.Typed<Element>` (on `Hash.Table.Bucket.Ops`) |

#### Package API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 22 | `package` | `static func bucket(for hash: Int, capacity: Index<Bucket>.Count) -> Bucket.Index` |

#### Public API (on `Hash.Table` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 35 | `public` | `var bucket: Bucket.Ops.View` (computed, `_read`) |

#### Public API (on `Property.View.Typed` where `Tag == Bucket.Ops, Base == Hash.Table`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 51 | `public` | `func for(hash: Int) -> Hash.Table<Element>.Bucket.Index` |
| 62 | `public` | `func next(_ bucket: Hash.Table<Element>.Bucket.Index) -> Hash.Table<Element>.Bucket.Index` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table.Static+ForEach.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `enum ForEach` (nested in `Hash.Table.Static`, with `typealias View`) |
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.ForEach, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>` |

#### Public API (on `Hash.Table.Static` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 28 | `public` | `var forEach: ForEach.View` (computed, `_read`) |

#### Public API (on `Property.View.Typed.Valued` where `Tag == ForEach, Base == Hash.Table.Static`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 42 | `public` | `func occupied(_ body: (Hash.Table<Element>.Bucket.Index, Index<Element>.Bounded<n>) -> Void)` |
| 52 | `public` | `func position(_ body: (Index<Element>.Bounded<n>) -> Void)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table.Static.Positions.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `enum Positions` (nested in `Hash.Table.Static`, with `typealias View`) |
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.Positions, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>` |

#### Public API (on `Hash.Table.Static` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 24 | `public` | `var positions: Positions.View` (computed, `_read`/`_modify`) |

#### Public API (on `Property.View.Typed.Valued` where `Tag == Positions, Base == Hash.Table.Static`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 42 | `public` | `mutating func decrement(after removedPosition: Index<Element>.Bounded<n>)` |
| 55 | `public` | `mutating func update(forHash hashValue: Hash.Value, equals: (Index<Element>.Bounded<n>) -> Bool, newPosition: Index<Element>.Bounded<n>) -> Bool` (`@discardableResult`) |
| 76 | `public` | `mutating func update<Context: ~Copyable>(forHash hashValue: Hash.Value, context: borrowing Context, equals: (Index<Element>.Bounded<n>, borrowing Context) -> Bool, newPosition: Index<Element>.Bounded<n>) -> Bool` (`@discardableResult`) |
| 95 | `public` | `mutating func update(atBucket bucket: Hash.Table<Element>.Bucket.Index, newPosition: Index<Element>.Bounded<n>)` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table.Static+Removal.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `enum Remove` (nested in `Hash.Table.Static`, with `typealias View`) |
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.Remove, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>` |

#### Public API (on `Hash.Table.Static` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 24 | `public` | `var remove: Remove.View` (computed, `_read`/`_modify`) |

#### Public API (on `Property.View.Typed.Valued` where `Tag == Remove, Base == Hash.Table.Static`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 39 | `public` | `mutating func all()` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Table.Static+Bucket.swift`

#### Type Declarations

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `enum Ops` (nested in `Hash.Table.Static`, with `typealias View`) |
| 17 | `public` | `typealias View = Property<Hash.Table<Element>.Bucket.Ops, Hash.Table<Element>.Static<bucketCapacity>>.View.Typed<Element>.Valued<bucketCapacity>` |

#### Public API (on `Hash.Table.Static` where `Element: ~Copyable`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 28 | `public` | `var bucket: Ops.View` (computed, `_read`) |

#### Public API (on `Property.View.Typed.Valued` where `Tag == Bucket.Ops, Base == Hash.Table.Static`)

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 42 | `public` | `func for(hash: Int) -> Hash.Table<Element>.Bucket.Index` |
| 50 | `public` | `func next(_ current: Hash.Table<Element>.Bucket.Index) -> Hash.Table<Element>.Bucket.Index` |

---

### `Sources/Hash Table Accessor Primitives/Hash.Occupied.Static+Sequence.Protocol.swift`

#### Conformances

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `extension Hash.Occupied.Static: Sequence.Protocol` |
| 20 | `public` | `extension Hash.Occupied.Static: Swift.Sequence` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 24 | `public` | `var underestimatedCount: Int` (computed) |

---

### `Sources/Hash Table Accessor Primitives/Hash.Occupied.View+Sequence.Protocol.swift`

#### Conformances

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 16 | `public` | `extension Hash.Occupied.View: @unsafe Sequence.Protocol` |
| 20 | `public` | `extension Hash.Occupied.View: @unsafe Swift.Sequence` |

#### Public API

| Line | Visibility | Declaration |
|------|-----------|-------------|
| 24 | `public` | `var underestimatedCount: Int` (computed) |

---

## Summary

### @_spi Annotations

None found in any source file.

### Type Hierarchy

```
Hash
 +-- Occupied<Source: ~Copyable>                  [Copyable, Sendable]
 |    +-- Static<let bucketCapacity: Int>          [Copyable, Sendable]
 |    |    +-- Iterator                            [Sequence.Iterator.Protocol, IteratorProtocol]
 |    +-- View                                     [@unsafe, Copyable, @unchecked Sendable]
 |         +-- Iterator                            [@unsafe, Sequence.Iterator.Protocol, IteratorProtocol]
 +-- Table<Element: ~Copyable>                     [~Copyable, conditionally Copyable/Sendable]
      +-- Bucket                                   [~Copyable]
      |    +-- Index (typealias)
      |    +-- Ops (enum)
      +-- Positions (enum)
      +-- ForEach (enum)
      +-- Remove (enum)
      +-- Static<let bucketCapacity: Int>           [~Copyable, conditionally Copyable/Sendable]
           +-- Bucket (typealias)
           +-- ForEach (enum, accessor module)
           +-- Positions (enum, accessor module)
           +-- Remove (enum, accessor module)
           +-- Ops (enum, accessor module)
```

### Public Method Count by Category

| Category | Hash.Table (heap) | Hash.Table.Static (inline) |
|----------|-------------------|----------------------------|
| Init | 1 | 1 |
| Properties | 3 (`count`, `isEmpty`, `capacity`) | 6 (`count`, `isEmpty`, `capacity`, `occupancy`, `shouldGrow`, `isFull`) |
| Lookup | 4 (`position` x2, `index` x2) | 6 (`position` x2, `index` x2, `contains` x2) |
| Insertion | 3 (equals, context, unchecked) | 3 (equals, context, unchecked) |
| Removal | 3 (`remove` x2 + `remove(at:)`) | 4 (`remove` x2, `remove(atBucket:)`, `rehash`) |
| Iteration | `occupied` property, `forEach.occupied` | `occupied` property, `forEach.occupied`, `forEach.position` |
| Position Updates | `positions.decrement(after:)` | `positions.decrement(after:)`, `positions.update` x3 |
| Bucket Ops | `bucket.for(hash:)`, `bucket.next(_:)` | `bucket.for(hash:)`, `bucket.next(_:)` |
| CoW | `ensureUnique()` (Copyable only) | N/A (value type) |
| Bulk Remove | `remove.all(keepingCapacity:)` | `remove.all()` |
