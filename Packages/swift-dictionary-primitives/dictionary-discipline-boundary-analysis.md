# Dictionary Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) -> Storage (Tier 14) -> Buffer (Tier 15) -> Data Structure (Tier 16+)
```

`dictionary-primitives` sits at the top of this chain, composing `Set<Key>.Ordered` (for key management), `Buffer<Value>.Linear` (and its variants for value storage), and `Hash.Table` (for O(1) lookup in the Static variant) to present a consumer-facing ordered dictionary abstraction. The question: does `dictionary-primitives` contain ONLY dictionary-discipline semantics, or has buffer-level / hash-table-level / set-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-dictionary-primitives).

## Question

What semantics belong SOLELY to the dictionary abstraction layer, and does `dictionary-primitives` currently contain anything that properly belongs to the buffer, hash table, or set layers?

---

## Prior Art Survey

### Source 1: Formal ADT Theory (Liskov & Guttag, Axiomatic Semantics)

The formal ADT specification for an associative array (dictionary/map):

```
Operations: new(), get(d,k), put(d,k,v), delete(d,k), contains(d,k)

Axioms:
  get(put(d,k,v), k)    = v                       (read-after-write)
  get(put(d,k,v), k')   = get(d,k')  where k!=k'  (non-interference)
  contains(put(d,k,v), k) = true                   (membership after insert)
  contains(new(), k)     = false                   (empty has no keys)
  delete(put(d,k,v), k)  produces d' where
    contains(d',k) = false                         (deletion removes key)
  get(delete(d,k), k')   = get(d,k')  where k!=k' (delete non-interference)
```

The ADT mentions NO implementation concerns: no hash functions, no buckets, no probing, no tree rebalancing, no contiguous memory. The dictionary is purely the **key-value association contract with uniqueness and non-interference laws**.

This is the critical distinction from array: an array is indexed by dense integer positions, a dictionary is indexed by arbitrary keys drawn from an equality-comparable (and typically hashable) domain.

### Source 2: Rust `HashMap<K,V>` (std::collections)

Rust's `HashMap` presents a clear map abstraction over SwissTable:

- `insert(k, v) -> Option<V>` -- returns old value if key existed (upsert semantics)
- `get(&k) -> Option<&V>` -- immutable borrow by key
- `get_mut(&k) -> Option<&mut V>` -- mutable borrow by key
- `remove(&k) -> Option<V>` -- remove and return
- `contains_key(&k) -> bool` -- membership test
- `entry(k) -> Entry` -- the Entry API for in-place mutation
- `keys()`, `values()`, `values_mut()` -- projection iterators
- `len()`, `is_empty()`, `capacity()`
- `Eq` and `Hash` trait bounds on `K`

**Key separation**: Rust never exposes the SwissTable internals (bucket groups, SIMD masks, probing sequences) through `HashMap`. The hash table is entirely encapsulated. `HashMap` owns the semantic contract; SwissTable owns the performance mechanism.

### Source 3: C++ STL Associative Containers (Stepanov)

C++ separates associative containers into two concept hierarchies:

**AssociativeContainer** (`std::map`):
- Sorted by key using `Compare` (typically `operator<`)
- Logarithmic complexity guarantees: O(log n) find/insert/erase
- Iterator stability guarantees stronger than unordered variants
- `value_type` is `std::pair<const Key, T>`

**UnorderedAssociativeContainer** (`std::unordered_map`):
- Hash-based with amortized O(1) find/insert/erase
- Requires `Hash` and `KeyEqual`
- Bucket interface exposed (`bucket_count()`, `load_factor()`, `rehash()`)
- Iterator invalidation on rehash

Both share the dictionary-discipline semantics:
- Key uniqueness (`unique_keys = true`)
- `operator[]` with default-insert for missing keys
- `at()` with exception on missing keys
- `insert()`, `emplace()`, `erase()`, `find()`, `count()`, `contains()`
- Key and value projections via structured bindings

**Important**: C++ `unordered_map` notably leaks hash table implementation detail (bucket interface, load factor). This is widely considered a design mistake -- it conflates the dictionary abstraction with hash table mechanism.

### Source 4: Haskell `Data.Map` (Functional)

Haskell's `Data.Map` provides the purest algebraic view of dictionaries:

- **Functor over values**: `fmap f m` applies `f` to every value, preserving key structure
- **Foldable over values**: `foldr`, `foldl'` collapse values to summary
- **Traversable over values**: effectful transformation preserving key skeleton
- **Monoid under union**: `Map.union` with `Map.empty` as identity
- Key uniqueness as type-level invariant (balanced BST internally)

Purely dictionary-discipline operations:
- `lookup :: Ord k => k -> Map k a -> Maybe a`
- `insert :: Ord k => k -> a -> Map k a -> Map k a`
- `delete :: Ord k => k -> Map k a -> Map k a`
- `mapWithKey :: (k -> a -> b) -> Map k a -> Map k b`
- `filterWithKey :: (k -> a -> Bool) -> Map k a -> Map k a`
- `unionWith :: (a -> a -> a) -> Map k a -> Map k a -> Map k a`
- `intersectionWith :: (a -> b -> c) -> Map k a -> Map k b -> Map k c`
- `differenceWith :: (a -> b -> Maybe a) -> Map k a -> Map k b -> Map k a`

**Key insight**: `Data.Map` NEVER exposes its internal balanced tree structure (size-balanced trees). The tree is implementation; the key-value association is the abstraction.

### Source 5: Python `dict` (3.7+)

Python's `dict` made insertion-order preservation an official language guarantee in Python 3.7 (CPython implementation detail since 3.6):

- `d[k]` -- KeyError on missing (strict get)
- `d.get(k, default)` -- subscript-with-default
- `d[k] = v` -- upsert (insert or update)
- `del d[k]` -- remove
- `k in d` -- membership
- `d.keys()`, `d.values()`, `d.items()` -- projection views
- `d.update(other)` / `d | other` (3.9+) -- merge
- `d.pop(k, default)` -- remove with default
- `d.setdefault(k, default)` -- get-or-insert
- `len(d)`, `iter(d)` -- size and iteration

Python's dict internally uses a compact hash table with a dense key-value array and a sparse index table, but this is entirely hidden from the API. The insertion-order guarantee is a dictionary-discipline semantic, not a hash table requirement.

### Source 6: Swift stdlib `Dictionary` vs internal storage

Swift's `Dictionary` uses `_NativeDictionary` (hash table with open addressing and linear probing) internally. The public API exposes:

- `subscript(key:)` returning `Value?`
- `subscript(key:default:)` subscript-with-default
- `updateValue(_:forKey:)` -- upsert returning old value
- `removeValue(forKey:)` -- remove by key
- `keys`, `values` -- lazy projection collections
- `mapValues(_:)` -- transform values preserving keys
- `merge(_:uniquingKeysWith:)` -- merge with conflict resolution
- `filter(_:)` -- predicate-based filtering
- `compactMapValues(_:)` -- transform and compact values

Swift stdlib notably does NOT guarantee insertion order for `Dictionary`. The ordered variant is `OrderedDictionary` from swift-collections.

---

## Analysis

### What is SOLELY Dictionary Discipline

#### A. Key-Value Association Contract

The dictionary's primary contribution: the **semantic guarantee of key-value pairing**. This is the defining characteristic that distinguishes a dictionary from all lower layers.

| Contract | Explanation |
|----------|-------------|
| **Key uniqueness** | Each key maps to at most one value. Inserting a duplicate key updates the existing value rather than creating a second entry. This is enforced by delegating to `Set<Key>.Ordered` for key management. |
| **Non-interference** | Getting key `k'` after setting key `k` (where `k != k'`) returns the previous value for `k'`. Neither buffer nor hash table guarantees this at the semantic level. |
| **Upsert semantics** | `set(key, value)` either inserts (if key is new) or updates (if key exists). This if/else branch IS the dictionary -- buffer only knows `append` and `replace(at:)`. |
| **Key-indexed removal** | `remove(key)` finds the key's position, removes both key and value, and shifts subsequent entries. The coordination of key-position-lookup + value-removal + index-shifting is dictionary discipline. |
| **Insertion-order preservation** | The ordered dictionary guarantees that iteration order equals insertion order (minus removals). This is a semantic commitment beyond what any single lower layer provides. |
| **Order-sensitive equality** | `[a:1, b:2] != [b:2, a:1]` -- equality considers order. This is a dictionary-level semantic choice. |
| **Duplicate key detection** | `init(_ pairs:) throws(Error)` detects and reports duplicate keys with typed errors including position information. |

#### B. Protocol/Interface Conformance

The dictionary makes the key-value storage a citizen of the type system's protocol hierarchy.

| Conformance | What it provides | Why not in lower layers |
|-------------|-----------------|------------------------|
| `Sequence.Protocol` | Multi-pass iteration over `(key: Key, value: Value)` pairs | Buffer iterates over `Value`; Set iterates over `Key`; only Dictionary yields the paired tuple |
| `Swift.Sequence` | `for-in` loops and stdlib algorithm interop | Same -- the element type `(key: Key, value: Value)` is dictionary's |
| `Swift.Collection` | `startIndex`/`endIndex`/`index(after:)` with `Int` index | Makes dictionary usable as a random-access collection of pairs |
| `Swift.BidirectionalCollection` | `index(before:)` | Reverse traversal over pairs |
| `Swift.RandomAccessCollection` | O(1) distance, all random-access algorithms | Same |
| `Sequence.Clearable` | `removeAll()` enabling `.forEach.consuming { }` | Dictionary coordinates clearing both keys and values |
| `Equatable` | Order-sensitive element-wise equality | Buffer has no equality concept; Set equality ignores values |
| `Hashable` | Hash combining keys and values in order | Same |
| `CustomStringConvertible` | `"Dictionary.Ordered([a: 1, b: 2])"` | Human-readable key-value display |

#### C. Key and Value Projections

Projections are SOLELY dictionary discipline. No lower layer can provide them because they require knowledge of the key-value duality.

| Projection | What it provides |
|------------|-----------------|
| `dict.keys` | `Keys` struct with `index(_:)`, `contains(_:)`, `count`, `isEmpty`, subscripts, `all`, `Sequence` conformance |
| `dict.values` | `Values` struct with `set(_:_:)`, `remove(_:)`, `modify(_:_:)`, subscripts by index/key, `Sequence` conformance |
| `dict.keys.index(_:)` | Find position of key -- delegates to Set but the wrapper is dictionary's |
| `dict.values.modify(_:_:)` | In-place value mutation by key -- unique to dictionary |

#### D. Merge Operations

Merge is a dictionary-specific algebraic operation. Buffers can concatenate; sets can union. Only dictionaries can merge key-value pairs with conflict resolution.

| Operation | What it provides |
|-----------|-----------------|
| `dict.merge.keep.first(pairs)` | Merge, keeping existing values for duplicate keys |
| `dict.merge.keep.last(pairs)` | Merge, replacing with incoming values for duplicate keys |
| `init(_:uniquingKeysWith:)` | Construct from pairs with custom conflict resolution |

**Algebraic laws** documented in the codebase:
- Identity: `A.merge.keep.first([]) == A`
- Idempotence: `A.merge.keep.first(A) == A`
- Order preservation: merge never reorders existing keys

#### E. Dual-Storage Coordination

The dictionary's unique structural contribution: coordinating two parallel storage systems (keys and values) so they remain synchronized.

| Coordination | What it provides |
|-------------|-----------------|
| Key-value index correspondence | `_keys[i]` and `_values[i]` always refer to the same pair |
| Synchronized insertion | `set` appends to both keys and values atomically |
| Synchronized removal | `remove` removes from both and shifts both |
| Synchronized clearing | `clear` empties both key and value storage |
| Synchronized draining | `drain` consumes from both in order |
| CoW coordination | `makeUnique()` ensures value buffer uniqueness before mutation |

#### F. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Dictionary.Ordered` -- dynamically-growing | Wraps `Set<Key>.Ordered` + `Buffer<Value>.Linear` |
| `Dictionary.Ordered.Bounded` -- fixed capacity | Throws `.overflow` when full; compile-time capacity limit |
| `Dictionary.Ordered.Static<capacity>` -- inline storage | Zero-allocation with compile-time capacity; wraps `Hash.Table<Key>.Static` + `Buffer.Linear.Inline` |
| `Dictionary.Ordered.Small<inlineCapacity>` -- small-buffer optimization | Inline storage with automatic spill to heap |
| `Dictionary.Ordered.Entry` -- ~Copyable pair | Key-value struct supporting move-only values (tuples require Copyable) |
| Conditional `Copyable` | `Copyable where Value: Copyable` -- keys are always Copyable via `Hash.Protocol` |
| Conditional `Sendable` | `@unchecked Sendable where Key: Sendable, Value: Sendable` |

#### G. Typed Error Taxonomy

The dictionary defines its own error types that encode dictionary-specific failure modes.

| Error | What it means |
|-------|---------------|
| `.bounds(index, count)` | Index-based access out of bounds |
| `.empty` | Operation on empty dictionary |
| `.duplicate(key, first, second)` | Duplicate key detected during construction |
| `.overflow` | Bounded/Static dictionary is full |
| `.invalidCapacity` | Negative capacity in Bounded constructor |

These errors are dictionary-discipline because they encode key-specific context (the duplicate key itself, the conflicting positions).

#### H. ~Copyable Value Access Patterns

| Pattern | What it provides |
|---------|-----------------|
| `withValue(forKey:_:)` | Borrow value by key for ~Copyable values |
| `withValue(at:_:)` | Borrow value by index for ~Copyable values |
| `withValue(at:_:) throws` | Same with typed error on bounds failure |
| `drain { entry in }` | Consuming iteration for ~Copyable values via `Entry` struct |
| `forEach { key, value in }` | Borrowing iteration for ~Copyable values |

#### I. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Ordered`/`Bounded`/`Static`/`Small` family |
| `Dictionary.Ordered.Iterator` | Wraps buffer internals into `(key: Key, value: Value)` pairs |
| `subscript(key:) -> Value?` | Standard dictionary subscript (Copyable values only) |
| `subscript(at:) -> (key:, value:)` | Typed-index pair access |
| `subscript(index:) -> (key:, value:)` | Raw `Int` index access (stdlib compatibility) |
| `key(at:)`, `value(at:)`, `entry(at:)` | Named accessors for individual components |
| `contains(_:)` | Key membership test (thin delegation) |
| `reserve(_:)` | Reserve capacity for both keys and values simultaneously |
| `clear(keepingCapacity:)` | Consumer-facing boolean flag for retention |

#### J. Algebraic Structure (not yet implemented but canonically Dictionary's)

| Property | Dictionary owns it |
|----------|-------------------|
| Functor over values (`mapValues`) | Structure-preserving value transformation |
| Foldable over values (`reduce`) | Collapse to summary value |
| Monoid under `merge` | `merge.keep.last` with `[:]` as identity |
| Set-theoretic operations | `filter`, `intersection`, `difference` by key |
| `compactMapValues` | Transform and compact values |
| `subscript(key:default:)` | Subscript with default value |

### What Lower Layers Own (Dictionary Merely Delegates)

#### Set<Key>.Ordered Owns

| Concern | Owned by Set |
|---------|-------------|
| Key hashing | `Hash.Protocol` conformance |
| Key uniqueness enforcement | `insert(_:)` returns `(inserted: Bool, _)` |
| Key ordering | Insertion-order tracking |
| Key index lookup | `index(_:) -> Index?` |
| Key membership | `contains(_:)` |
| Key removal | `remove(_:)` |

#### Buffer<Value>.Linear Owns

| Concern | Owned by Buffer.Linear |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | `Buffer.Growth.Policy` |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Raw pointer access | `pointer(at:)` |
| Contiguous memory guarantee | `Span.Protocol` |
| Unchecked subscript | Direct pointer arithmetic |

#### Hash.Table Owns (Static variant only)

| Concern | Owned by Hash.Table |
|---------|-------------------|
| Hash function evaluation | `key.hashValue` |
| Open-addressed probing | Linear probing in `Hash.Table.Static` |
| Bucket management | Position allocation, collision resolution |
| Position tracking | `positions` array, `decrement(after:)` |
| Load factor and capacity constraints | Power-of-two capacity requirement |

---

## Audit: Current dictionary-primitives

### Audit Methodology

For each file in `dictionary-primitives`, classify every public API member as:
- **DICTIONARY**: Solely dictionary discipline (key-value contract, protocol conformance, projection, merge, ergonomics)
- **DELEGATE**: Pure delegation to lower layer (thin wrapper calling `_keys.foo` or `_values.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Dictionary Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `Dictionary<Key, Value>` namespace | Architecture | `Dictionary.Ordered.swift` |
| `Dictionary.Ordered` struct | Architecture | `Dictionary.Ordered.swift` |
| `Dictionary.Ordered.Entry` struct | ~Copyable pair type | `Dictionary.Ordered.swift` |
| `Dictionary.Ordered.Bounded` struct | Variant | `Dictionary.Ordered.swift` |
| `Dictionary.Ordered.Static<capacity>` struct | Variant | `Dictionary.Ordered.swift` |
| `Dictionary.Ordered.Small<inlineCapacity>` struct | Variant | `Dictionary.Ordered.swift` |
| Conditional `Copyable` on `.Ordered`, `.Bounded`, `.Entry` | Type invariant | `Dictionary.Ordered.swift` |
| `@unchecked Sendable` on all variants | Type invariant | `Dictionary.Ordered.swift` |
| `set(_:_:)` upsert (all variants, ~Copyable) | Key-value contract | `Dictionary.Ordered ~Copyable.swift` |
| `set(_:_:)` CoW upsert (Ordered, Copyable) | Key-value contract + CoW | `Dictionary.Ordered Copyable.swift` |
| `remove(_:)` by key (all variants) | Key-value contract | `Dictionary.Ordered ~Copyable.swift`, `Copyable.swift` |
| `clear(keepingCapacity:)` | Ergonomics | `Dictionary.Ordered ~Copyable.swift`, `Copyable.swift` |
| `init(reservingCapacity:)` | Initialization | `Dictionary.Ordered ~Copyable.swift` |
| `init(_ pairs:) throws` | Duplicate detection | `Dictionary.Ordered Copyable.swift` |
| `init(_:uniquingKeysWith:)` | Conflict resolution | `Dictionary.Ordered Copyable.swift` |
| `subscript(key:) -> Value?` (all variants, Copyable) | Dictionary subscript | `Dictionary.Ordered Copyable.swift` |
| `subscript(at:)`, `subscript(index:)` | Pair access | `Dictionary.Ordered Copyable.swift` |
| `key(at:)`, `value(at:)`, `entry(at:)` | Named pair access | `Dictionary.Index.swift` |
| `withValue(forKey:_:)` (all variants) | ~Copyable key access | `Dictionary.Ordered ~Copyable.swift` |
| `withValue(at:_:)` (all variants) | ~Copyable index access | `Dictionary.Ordered ~Copyable.swift` |
| `withValue(at:_:) throws` (all variants) | Typed-error index access | `Dictionary.Ordered ~Copyable.swift` |
| `forEach { key, value in }` | ~Copyable iteration | `Dictionary.Ordered ~Copyable.swift` |
| `drain { entry in }` on Ordered | ~Copyable consuming iteration | `Dictionary.Ordered ~Copyable.swift` (Ordered Primitives) |
| `Dictionary.Ordered.Drain` struct | Drain type | `Dictionary.Ordered ~Copyable.swift` (Ordered Primitives) |
| `Dictionary.Ordered.Keys` struct | Key projection | `Dictionary.Ordered.Keys.swift` |
| `dict.keys` property | Key projection accessor | `Dictionary.Ordered.Keys.swift` |
| `Keys.index(_:)`, `Keys.contains(_:)`, `Keys.count`, `Keys.isEmpty` | Key projection ops | `Dictionary.Ordered.Keys.swift` |
| `Keys.all` | Return underlying key set | `Dictionary.Ordered.Keys.swift` |
| `Keys` subscripts (typed + raw) | Key access by index | `Dictionary.Ordered.Keys.swift` |
| `Keys.Iterator`, `Keys: Swift.Sequence` | Key iteration | `Dictionary.Ordered.Keys.swift` |
| `Dictionary.Ordered.Values` struct | Value projection | `Dictionary.Ordered.Values.swift` |
| `dict.values` property with `_modify` | Value projection accessor | `Dictionary.Ordered.Values.swift` |
| `Values.set(_:_:)`, `Values.remove(_:)` | Value mutation by key | `Dictionary.Ordered.Values.swift` |
| `Values.modify(_:_:)` | In-place value mutation | `Dictionary.Ordered.Values.swift` |
| `Values.count`, `Values.isEmpty` | Value collection properties | `Dictionary.Ordered.Values.swift` |
| `Values` subscripts (typed, raw, key) | Value access | `Dictionary.Ordered.Values.swift` |
| `Values.Iterator`, `Values: Swift.Sequence` | Value iteration | `Dictionary.Ordered.Values.swift` |
| `Dictionary.Ordered.Merge` struct | Merge namespace | `Dictionary.Ordered.Merge.swift` |
| `dict.merge` property with `_modify` | Merge accessor | `Dictionary.Ordered.Merge.swift` |
| `Dictionary.Ordered.Merge.Keep` struct | Keep-policy namespace | `Dictionary.Ordered.Merge.Keep.swift` |
| `Keep.first(_:)` | Merge keeping existing | `Dictionary.Ordered.Merge.Keep.swift` |
| `Keep.last(_:)` | Merge keeping incoming | `Dictionary.Ordered.Merge.Keep.swift` |
| `__DictionaryOrderedError` | Typed error | `Dictionary.Ordered.Error.swift` |
| `__DictionaryOrderedBoundedError` | Typed error | `Dictionary.Ordered.Error.swift` |
| `__DictionaryOrderedInlineError` | Typed error | `Dictionary.Ordered.Error.swift` |
| Error `CustomStringConvertible` | Ergonomics | `Dictionary.Ordered.Error.swift` |
| `Dictionary.Index` typealias | Typed indexing | `Dictionary.Index.swift` |
| `Equatable` on `.Ordered`, `.Bounded` | Algebraic | `Dictionary.Ordered Copyable.swift` |
| `Hashable` on `.Ordered`, `.Bounded` | Algebraic | `Dictionary.Ordered Copyable.swift` |
| `CustomStringConvertible` on `.Ordered` | Ergonomics | `Dictionary.Ordered Copyable.swift` |
| `Dictionary.Ordered.Iterator` (Ordered, Bounded, Static, Small) | Iterator types | All variant Copyable files |
| `Sequence.Protocol` conformance (all variants) | Protocol | All variant files |
| `Swift.Sequence` conformance (Ordered, Bounded) | Protocol bridge | `Dictionary.Ordered Copyable.swift` (Ordered Primitives), `Dictionary.Ordered.Bounded Copyable.swift` |
| `Swift.Collection` conformance (Ordered, Bounded) | Protocol | Same |
| `Swift.BidirectionalCollection` (Ordered, Bounded) | Protocol | Same |
| `Swift.RandomAccessCollection` (Ordered, Bounded) | Protocol | Same |
| `Sequence.Clearable` conformance (all variants) | Protocol | All variant files |
| `element(at:) throws` on Ordered | Typed-error access | `Dictionary.Ordered Copyable.swift` (Ordered Primitives) |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `_keys.count` | Set<Key>.Ordered | **OK** -- dictionary surface for key-set state |
| `var isEmpty` -> `_keys.isEmpty` | Set<Key>.Ordered | **OK** |
| `var capacity` -> `_values.capacity.retag(Key.self)` | Buffer<Value>.Linear | **OK** |
| `contains(_:)` -> `_keys.contains(_:)` | Set<Key>.Ordered | **OK** -- dictionary exposes key membership |
| `reserve(_:)` -> `_keys.reserve` + `ensureCapacity` | Set + Buffer | **OK** -- coordinates both layers |
| `makeUnique()` -> `_values.ensureUnique()` | Buffer<Value>.Linear | **OK** -- CoW delegation |
| `Keys.index(_:)` -> `_keys.index(_:)` | Set<Key>.Ordered | **OK** |
| `Keys.contains(_:)` -> `_keys.contains(_:)` | Set<Key>.Ordered | **OK** |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `Dictionary.Ordered.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** -- a user reasonably wants to know if their small dictionary has spilled to heap. This is a valid consumer-facing diagnostic property, identical to `Array.Small.isSpilled`. Keep it, but document it as a diagnostic, not a contract. |
| `isFull` on Bounded and Static | Exposes capacity state. | **OK** -- for bounded/static containers, knowing "is this full?" is a dictionary-discipline property. The user needs this to decide whether to insert. |
| `_spillKeysToHeap()` on Small | Internal spill logic exposed at `@usableFromInline`. | **OK** -- this is `@usableFromInline`, not `public`. It's ABI-visible for inlining but not consumer-facing API. The spill coordination (keys spill alongside values) is dictionary-discipline. |
| `_hashTable` operations in Static `set`/`remove`/`contains` | Dictionary.Ordered.Static directly calls `_hashTable.position(forHash:equals:)`, `_hashTable.insert(...)`, `_hashTable.remove(...)`, `_hashTable.positions.decrement(after:)`. | **MINOR CONCERN** -- This is necessary because Static cannot delegate to `Set<Key>.Ordered` (no heap allocation allowed). The hash table interaction is implementation detail, but it's correctly encapsulated within the dictionary's methods. The public API exposes only dictionary semantics (`set`, `remove`, `contains`). However, `_hashTable.positions.decrement(after:)` is a hash-table-specific concern (index shifting after removal) that leaks into dictionary code. Consider whether Hash.Table should provide a higher-level `remove-and-shift` operation. |
| `index(of:)` on Static returns `Index<Key>.Bounded<capacity>` | Exposes bounded index type from hash table layer. | **MINOR** -- the bounded index type is appropriate for a compile-time-capacity container. The type `Index<Key>.Bounded<capacity>` is from index-primitives, not hash-table-primitives. This is fine. |
| Static's `_keys: Buffer<Key>.Linear.Inline<capacity>` and `_hashTable: Hash.Table<Key>.Static<capacity>` | Static variant manages its own hash table rather than delegating to Set. | **ARCHITECTURAL NOTE** -- This is correct by necessity. `Set<Key>.Ordered` uses heap allocation, which `Static` cannot. The duplication of hash-table integration logic is the cost of the zero-allocation guarantee. |
| Small's dual-mode key storage (`_inlineKeys` + `_heapKeys`) | Manages two different key storage strategies. | **OK** -- this is the small-buffer optimization pattern. The coordination of inline-to-heap transition for keys is dictionary-discipline because it must keep keys synchronized with the value buffer's own spill. |
| `_values: Buffer<Value>.Linear` is `public` | Stored property visibility. | **MINOR LEAK** -- `_values` is `public`, meaning consumers can access the raw value buffer. Convention suggests `package` access. However, this matches the pattern used in array-primitives where `_buffer` is also exposed. |
| `_keys: Set<Key>.Ordered` is `public` | Stored property visibility. | **Same as above** -- `_keys` is `public`. |
| `withValue(atIndex:_:)` on Static/Small takes raw `Int` | Bypasses typed indexing for raw Int access. | **MINOR** -- provides stdlib-compatible access path. Consider whether this should be the only untyped access or whether typed `withValue(at: Index<Key>)` should be preferred. Both are provided, which is fine for ergonomics. |

### What's MISSING from Dictionary (things that are solely dictionary discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `subscript(key:default:)` | Ergonomics | High -- subscript-with-default is core dictionary semantics (Python `d.get(k, default)`, Swift stdlib `dict[key, default:]`) |
| `mapValues(_:)` | Functor | High -- transform all values preserving keys and order |
| `compactMapValues(_:)` | Functor | Medium -- transform and compact values |
| `filter(_:)` returning dictionary | Predicate | Medium -- filter by key-value predicate |
| `updateValue(_:forKey:) -> Value?` | Upsert | Medium -- standard dictionary operation returning old value |
| Set-theoretic operations (`intersection`, `difference`) | Algebraic | Low -- advanced dictionary algebra |
| `Equatable` / `Hashable` on Static and Small | Algebraic | Medium -- Static/Small are ~Copyable so cannot conform to `Equatable`, but could provide `isEqual(to:)` methods |
| `Codable where Key: Codable, Value: Codable` | Serialization | Low for primitives |
| `ExpressibleByDictionaryLiteral` | Syntax sugar | Medium -- `[key: value]` literal syntax |
| `merge.keep.first/last` on Bounded/Static/Small | Merge | Low -- currently merge is only on Ordered |
| `Values.map(_:)` returning array of values | Projection | Low |
| `keys` / `values` projections on Bounded/Static/Small | Projection | Medium -- currently only on Ordered |
| `entry(at:)` on Bounded/Static/Small | Named access | Low |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: dictionary-primitives is well-layered

The current `dictionary-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Key-value association contract** (upsert, key-indexed removal, dual-storage coordination) -- solely dictionary discipline
2. **Protocol conformance** (Sequence, Collection, Equatable, Hashable) -- solely dictionary discipline
3. **Key/Value projections** (Keys, Values structs) -- solely dictionary discipline
4. **Merge operations** (keep.first, keep.last) -- solely dictionary discipline
5. **Pure delegation** -- thin wrappers over Set and Buffer with dictionary-level preconditions

### Specific Recommendations

#### 1. Add `subscript(key:default:)` (High Priority)

Subscript-with-default is core dictionary semantics present in every major language's dictionary implementation. Its absence is a functional gap.

```swift
public subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
    get { self[key] ?? defaultValue() }
}
```

#### 2. Add `mapValues(_:)` (High Priority)

This is the dictionary-specific functor operation: transform all values while preserving key structure and order. Unlike `map`, which transforms the entire element, `mapValues` preserves the key skeleton.

#### 3. Encapsulate `_hashTable.positions.decrement(after:)` (Low Priority)

In `Dictionary.Ordered.Static.remove(_:)`, the call to `_hashTable.positions.decrement(after:)` is a hash-table-specific concern. Consider whether `Hash.Table` should provide a `remove(hashValue:equals:shiftAfter:)` method that handles the position decrement internally. This would improve layering for all consumers of Hash.Table.

#### 4. Consider `package` access for `_keys` and `_values` (Low Priority)

The stored properties `_keys` and `_values` are `public` on all variants. While this matches the array-primitives pattern (where `_buffer` is also exposed), `package` access would be more appropriate since these are implementation details. This is a cosmetic/convention issue, not a layering violation.

#### 5. `isSpilled` is acceptable (No Action)

`Dictionary.Ordered.Small.isSpilled` exposes a buffer detail, but it's a diagnostic property that users legitimately need. The SmallDict pattern's value proposition depends on knowing when you've spilled. Keep it.

#### 6. No lower-layer concerns have leaked upward (Confirmed)

The audit found **zero instances** of dictionary-primitives doing work that properly belongs solely to the buffer, hash table, or set layers. All storage management, growth, CoW, element lifecycle, hash probing, and contiguous-memory operations are handled by lower layers. The dictionary adds only:
- Key-value coordination logic (synchronizing two storage systems)
- Semantic contracts (upsert, merge, projections, typed errors)
- Protocol conformances over paired elements

The one area of note is `Dictionary.Ordered.Static`, which directly integrates `Hash.Table` rather than delegating to `Set<Key>.Ordered`. This is correct by design -- Static's zero-allocation constraint prevents use of Set (which heap-allocates). The hash table logic is properly encapsulated within dictionary-discipline methods.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure dictionary discipline | 55+ distinct APIs | Correctly placed |
| Pure delegation | 8 passthrough properties/methods | Correctly placed -- thin wrapping is the design intent |
| Lower-layer concern leaked into dictionary | **0** | Clean separation |
| Dictionary concern missing | 10-12 items | Future work, not a layering violation |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms for associative arrays
- [Associative array - Wikipedia](https://en.wikipedia.org/wiki/Associative_array): Formal definition and cross-language survey
- [HashMap in std::collections - Rust](https://doc.rust-lang.org/std/collections/struct.HashMap.html): Map abstraction over SwissTable
- [Storing Keys with Associated Values in Hash Maps - The Rust Programming Language](https://doc.rust-lang.org/book/ch08-03-hash-maps.html): Rust HashMap user-facing semantics
- [std::unordered_map - cppreference.com](https://en.cppreference.com/w/cpp/container/unordered_map.html): C++ UnorderedAssociativeContainer concept
- [std::map - cppreference.com](https://en.cppreference.com/w/cpp/container/map.html): C++ AssociativeContainer concept
- [Haskell Data.Map](https://wiki.haskell.org/Foldable_and_Traversable): Functor/Foldable/Traversable hierarchy
- [PEP 372 - Adding an ordered dictionary to collections](https://peps.python.org/pep-0372/): Python OrderedDict proposal
- [Python dict insertion order](https://discuss.python.org/t/no-explicit-mention-that-dicts-are-ordered-and-preserve-insertion-order/85063): Order guarantee in Python 3.7+
- [ADT Axiomatic Semantics - COMP 410](https://www.cs.unc.edu/~stotts/COMP410/adt/): Formal ADT specification methodology
- [ADT: Abstract Data Types - Software Foundations](https://softwarefoundations.cis.upenn.edu/vfa-current/ADT.html): Verified functional table axioms
- `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Research/value-storage-buffer-layering.md`
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`
