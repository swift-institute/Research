# Array Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-array-primitives to inventory all public operations and compare against canonical Array ADT operations.

**Trigger**: [RES-012] Discovery — proactive operations audit across 13 data structure packages.

**Scope**: Package-specific (swift-array-primitives).

## Question

Does swift-array-primitives provide the canonical operations expected of the Array ADT? Which operations are present, which are missing, and which missing operations are intentionally absent at the primitives layer?

## Canonical Operations (ADT Reference)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| access(i) | O(1) | Read element at index |
| update(i, x) | O(1) | Write element at index |
| append(x) | O(1) amortized | Add to end |
| insert(i, x) | O(n) | Insert at position (shift) |
| delete(i) | O(n) | Remove at position (shift) |
| pop_back() | O(1) | Remove last element |
| iterate | O(n) | Visit all elements |
| find(x) | O(n) | Linear search |
| size/count | O(1) | Number of elements |
| isEmpty | O(1) | Empty check |
| capacity | O(1) | Current capacity |

## Current Operations Inventory

### Variant: Dynamic (Array / Array.Dynamic)

**Storage**: Growable, heap-allocated via `Buffer<Element>.Linear`. CoW when `Element: Copyable`.

| Canonical Operation | Method/Property | Complexity | Source File | Constraint |
|---------------------|----------------|------------|-------------|------------|
| access(i) | `subscript(index: Index) -> Element` (`_read`) | O(1) | `Array.Dynamic ~Copyable.swift:74-78` | `~Copyable` |
| access(i) | `subscript(index: Index) -> Element` (`get`) | O(1) | `Array.Dynamic Copyable.swift:27-31` | `Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`_modify`) | O(1) | `Array.Dynamic ~Copyable.swift:79-83` | `~Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`set`) | O(1) | `Array.Dynamic Copyable.swift:32-36` | `Copyable` |
| append(x) | `mutating func append(_ element: consuming Element)` | O(1) amortized | `Array.Dynamic ~Copyable.swift:115-117` | `~Copyable` |
| append(x) | `mutating func append(_ element: Element)` | O(1) amortized | `Array.Dynamic Copyable.swift:70-72` | `Copyable` |
| insert(i, x) | **MISSING** | — | — | — |
| delete(i) | **MISSING** | — | — | — |
| pop_back() | `mutating func removeLast() -> Element?` | O(1) | `Array.Dynamic ~Copyable.swift:124-127` | `~Copyable` |
| pop_back() | `mutating func removeLast() -> Element?` | O(1) | `Array.Dynamic Copyable.swift:76-79` | `Copyable` |
| iterate | `makeIterator() -> Iterator` | O(n) | `Array.Dynamic.swift:90-98` | `Copyable` |
| iterate | `.forEach { }` (borrowing via Property.View) | O(n) | `Array.Dynamic ~Copyable.swift:228-235` | `~Copyable` |
| iterate | `.forEach.borrowing { }` | O(n) | `Array.Dynamic ~Copyable.swift:239-241` | `~Copyable` |
| iterate | `.drain { }` (consuming via Property.View) | O(n) | `Array.Dynamic ~Copyable.swift:273-278` | `~Copyable` |
| iterate | `.forEach.consuming { }` | O(n) | `Array.Dynamic Copyable.swift:100-104` | `Copyable` |
| find(x) | **MISSING** (requires `Equatable`) | — | — | — |
| size/count | `var count: Index.Count` | O(1) | `Array.Dynamic ~Copyable.swift:49-51` | `~Copyable` |
| isEmpty | `var isEmpty: Bool` | O(1) | `Array.Dynamic ~Copyable.swift:55` | `~Copyable` |
| capacity | `var capacity: Index.Count` | O(1) | `Array.Dynamic ~Copyable.swift:59` | `~Copyable` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Source File | Constraint |
|-----------|----------------|-------------|------------|
| Safe access | `func element(at index: Index) -> Element?` | `Array.Dynamic Copyable.swift:46-49` | `Copyable` |
| Offset access | `func element(at base: Index, offsetBy offset: Index.Offset) -> Element?` | `Array.Dynamic Copyable.swift:53-60` | `Copyable` |
| Borrow access | `func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R` | `Array.Dynamic ~Copyable.swift:99-102` | `~Copyable` |
| Clear all | `mutating func removeAll(keepingCapacity: Bool = false)` | `Array.Dynamic ~Copyable.swift:133-138` | `~Copyable` |
| Read-only span | `var span: Swift.Span<Element>` | `Array.Dynamic ~Copyable.swift:148-153` | `~Copyable` |
| Mutable span | `var mutableSpan: MutableSpan<Element>` | `Array.Dynamic ~Copyable.swift:157-162` | `~Copyable` |
| Unsafe read | `func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Dynamic ~Copyable.swift:177-181` | `Copyable`, `@_spi(Unsafe)` |
| Unsafe write | `mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Dynamic ~Copyable.swift:189-193` | `Copyable`, `@_spi(Unsafe)` |
| Indexed navigation | `var startIndex: Index` | `Array.Dynamic ~Copyable.swift:26` | `~Copyable` |
| Indexed navigation | `var endIndex: Index` | `Array.Dynamic ~Copyable.swift:29` | `~Copyable` |
| Forward index | `func index(after i: Index) -> Index` | `Array.Dynamic ~Copyable.swift:32` | `~Copyable` |
| Backward index | `func index(before i: Index) -> Index` | `Array.Dynamic ~Copyable.swift:39` | `~Copyable` |
| Array literal | `init(arrayLiteral elements: Element...)` | `Array+ExpressibleByArrayLiteral.swift:3-12` | `Copyable` |
| Underestimated count | `var underestimatedCount: Int` | `Array.Dynamic.swift:32` | `Copyable` |

**Protocol conformances**: `Collection.Protocol`, `Collection.Access.Random`, `Collection.Indexed` (deleted 2026-06), `Collection.Bidirectional`, `Sequence.Protocol`, `Swift.Sequence`, `Swift.Collection`, `Swift.BidirectionalCollection`, `Swift.RandomAccessCollection`, `ExpressibleByArrayLiteral`, `Copyable where Element: Copyable`, `@unchecked Sendable where Element: Sendable`.

**Phantom-typed wrapper**: `Array.Indexed<Tag>` with `count`, `isEmpty`, `capacity`, `subscript(index:)`, `append(_:)`, `removeLast()`, `removeAll(keepingCapacity:)`.

---

### Variant: Fixed (Array.Fixed)

**Storage**: Fixed-count, heap-allocated via `Buffer<Element>.Linear.Bounded`. CoW when `Element: Copyable`. All elements initialized at creation time; no `append`, no `removeLast`.

| Canonical Operation | Method/Property | Complexity | Source File | Constraint |
|---------------------|----------------|------------|-------------|------------|
| access(i) | `subscript(index: Index) -> Element` (`_read`) | O(1) | `Array.Fixed ~Copyable.swift:188-192` | `~Copyable` |
| access(i) | `subscript(index: Index) -> Element` (`get`) | O(1) | `Array.Fixed Copyable.swift:36-39` | `Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`_modify`) | O(1) | `Array.Fixed ~Copyable.swift:193-197` | `~Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`set`) | O(1) | `Array.Fixed Copyable.swift:40-45` | `Copyable` |
| append(x) | N/A — fixed-count, cannot grow | — | — | — |
| insert(i, x) | N/A — fixed-count, cannot grow | — | — | — |
| delete(i) | N/A — fixed-count, cannot shrink | — | — | — |
| pop_back() | N/A — fixed-count, cannot shrink | — | — | — |
| iterate | `makeIterator() -> Array.Fixed.Iterator` | O(n) | `Array.Fixed ~Copyable.swift:103-111` | `Copyable` (Iterator requires it) |
| iterate | `.forEach { }` (borrowing via Property.View) | O(n) | `Array.Fixed ~Copyable.swift:144-151` | `~Copyable` |
| iterate | `.forEach.borrowing { }` | O(n) | `Array.Fixed ~Copyable.swift:155-157` | `~Copyable` |
| find(x) | **MISSING** (requires `Equatable`) | — | — | — |
| size/count | `var count: Index.Count` | O(1) | `Array.Fixed ~Copyable.swift:167` | `~Copyable` |
| isEmpty | `var isEmpty: Bool` | O(1) | `Array.Fixed ~Copyable.swift:171` | `~Copyable` |
| capacity | `var capacity: Index.Count` | O(1) | `Array.Fixed ~Copyable.swift:175` | `~Copyable` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Source File | Constraint |
|-----------|----------------|-------------|------------|
| Safe access | `func element(at index: Index) -> Element?` | `Array.Fixed Copyable.swift:79-82` | `Copyable` |
| Offset access | `func element(at base: Index, offsetBy offset: Index.Offset) -> Element?` | `Array.Fixed Copyable.swift:64-71` | `Copyable` |
| Borrow access | `func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R` | `Array.Fixed ~Copyable.swift:207-210` | `~Copyable` |
| Checked init | `init(count:initializingWith:) throws(Error)` | `Array.Fixed.swift:28-52` (Core) | `~Copyable` |
| Unchecked init | `init(__unchecked:count:initializingWith:)` | `Array.Fixed.swift:68-91` (Core) | `~Copyable` |
| Read-only span | `var span: Swift.Span<Element>` | `Array.Fixed ~Copyable.swift:245-250` | `~Copyable` |
| Mutable span | `var mutableSpan: MutableSpan<Element>` | `Array.Fixed ~Copyable.swift:254-259` | `~Copyable` |
| CoW mutable span | `var mutableSpan: MutableSpan<Element>` | `Array.Fixed Copyable.swift:53-58` | `Copyable` |
| Unsafe read | `func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Fixed ~Copyable.swift:222-225` | `Copyable`, `@_spi(Unsafe)` |
| Unsafe write | `mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Fixed ~Copyable.swift:231-235` | `Copyable`, `@_spi(Unsafe)` |
| Indexed navigation | `startIndex`, `endIndex`, `index(after:)`, `index(before:)` | `Array.Fixed ~Copyable.swift:32-49` | `~Copyable` |
| Underestimated count | `var underestimatedCount: Int` | `Array.Fixed Copyable.swift:21` | `Copyable` |

**Protocol conformances**: `Collection.Protocol`, `Collection.Access.Random`, `Collection.Indexed` (deleted 2026-06), `Collection.Bidirectional`, `Sequence.Protocol`, `Swift.Sequence`, `Swift.Collection`, `Swift.BidirectionalCollection`, `Swift.RandomAccessCollection`, `Copyable where Element: Copyable`, `@unchecked Sendable where Element: Sendable`.

**Error type**: `Array.Fixed.Error` with cases `.invalidCount(Array.Index.Count)` and `.indexOutOfBounds(index:count:)`.

**Phantom-typed wrapper**: `Array.Fixed.Indexed<Tag>` with `count`, `isEmpty`, `subscript(index:)` (`_read`/`_modify` for `~Copyable`, `get`/`set` for `Copyable`), `Sendable where Element: Sendable`.

---

### Variant: Static (Array.Static\<capacity\>)

**Storage**: Fixed-capacity inline storage via `Buffer<Element>.Linear.Inline<capacity>`. No heap allocation. Unconditionally `~Copyable` (deinit required). Variable count (0 to capacity).

| Canonical Operation | Method/Property | Complexity | Source File | Constraint |
|---------------------|----------------|------------|-------------|------------|
| access(i) | `subscript(index: Index) -> Element` (`_read`) | O(1) | `Array.Static ~Copyable.swift:77-80` | `~Copyable` |
| access(i) | `subscript(index: Index) -> Element` (`get`) | O(1) | `Array.Static Copyable.swift:27-30` | `Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`_modify`) | O(1) | `Array.Static ~Copyable.swift:81-85` | `~Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`set`) | O(1) | `Array.Static Copyable.swift:31-35` | `Copyable` |
| append(x) | `mutating func append(_ element: consuming Element) throws(Array.Static.Error)` | O(1) | `Array.Static ~Copyable.swift:112-117` | `~Copyable` |
| insert(i, x) | **MISSING** | — | — | — |
| delete(i) | **MISSING** | — | — | — |
| pop_back() | `mutating func removeLast() -> Element?` | O(1) | `Array.Static ~Copyable.swift:123-126` | `~Copyable` |
| iterate | `makeIterator() -> Buffer<Element>.Linear.Inline<capacity>.Iterator` | O(n) | `Array Static.swift:52-54` | `Copyable` (Iterator requires it) |
| iterate | `.forEach { }` (borrowing via Property.View) | O(n) | `Array.Static ~Copyable.swift:190-197` | `~Copyable` |
| iterate | `.forEach.borrowing { }` | O(n) | `Array.Static ~Copyable.swift:201-203` | `~Copyable` |
| iterate | `.drain { }` (consuming via Property.View) | O(n) | `Array.Static ~Copyable.swift:224-230` | `~Copyable` |
| iterate | `.forEach.consuming { }` | O(n) | `Array.Static Copyable.swift:99-107` | `Copyable` |
| find(x) | **MISSING** (requires `Equatable`) | — | — | — |
| size/count | `var count: Index.Count` | O(1) | `Array.Static ~Copyable.swift:51-53` | `~Copyable` |
| isEmpty | `var isEmpty: Bool` | O(1) | `Array.Static ~Copyable.swift:57` | `~Copyable` |
| capacity | **Implicit** (compile-time generic parameter `capacity`) | O(0) | — | — |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Source File | Constraint |
|-----------|----------------|-------------|------------|
| isFull | `var isFull: Bool` | `Array.Static ~Copyable.swift:61` | `~Copyable` |
| Safe access | `func element(at index: Index) -> Element?` | `Array.Static Copyable.swift:46-49` | `Copyable` |
| Offset access | `func element(at base: Index, offsetBy offset: Index.Offset) -> Element?` | `Array.Static Copyable.swift:54-62` | `Copyable` |
| Borrow access | `func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R` | `Array.Static ~Copyable.swift:96-99` | `~Copyable` |
| Clear all | `mutating func removeAll()` | `Array.Static ~Copyable.swift:130-133` | `~Copyable` |
| Span access | `func withSpan<R, E>(_:) throws(E) -> R` | `Array.Static ~Copyable.swift:143-147` | `~Copyable` |
| Mutable span | `mutating func withMutableSpan<R, E>(_:) throws(E) -> R` | `Array.Static ~Copyable.swift:151-155` | `~Copyable` |
| Unsafe read | `func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Static Copyable.swift:74-78` | `Copyable`, `@_spi(Unsafe)` |
| Unsafe write | `mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Static Copyable.swift:83-87` | `Copyable`, `@_spi(Unsafe)` |
| Indexed navigation | `startIndex`, `endIndex`, `index(after:)`, `index(before:)` | `Array.Static ~Copyable.swift:25-41` | `~Copyable` |

**Protocol conformances**: `Collection.Protocol`, `Collection.Access.Random`, `Collection.Indexed` (deleted 2026-06), `Collection.Bidirectional`, `Collection.Remove.Last`, `Collection.Clearable`, `Sequence.Protocol`, `@unchecked Sendable where Element: Sendable`.

**Note**: Cannot conform to `Swift.Collection` because `Array.Static` is unconditionally `~Copyable`.

**Error type**: `Array.Static.Error` (typealias to `__ArrayStaticError`) with cases `.overflow` and `.indexOutOfBounds(index:count:)`. Conforms to `CustomStringConvertible`.

**Phantom-typed wrapper**: `Array.Static.Indexed<Tag>` with `count`, `isEmpty`, `isFull`, `subscript(index:)` (`_read`/`_modify` for `~Copyable`, `get`/`set` for `Copyable`), `withElement(at:_:)`, `element(at:)` (Copyable only), `append(_:)`, `removeLast()`, `removeAll()`, `Sendable where Element: Sendable`.

---

### Variant: Small (Array.Small\<inlineCapacity\>)

**Storage**: Inline storage with automatic spill to heap via `Buffer<Element>.Linear.Small<inlineCapacity>`. Unconditionally `~Copyable`.

| Canonical Operation | Method/Property | Complexity | Source File | Constraint |
|---------------------|----------------|------------|-------------|------------|
| access(i) | `subscript(index: Index) -> Element` (`_read`) | O(1) | `Array.Small ~Copyable.swift:82-84` | `~Copyable` |
| access(i) | `subscript(index: Index) -> Element` (`get`) | O(1) | `Array.Small Copyable.swift:25-28` | `Copyable` |
| update(i, x) | `subscript(index: Index) -> Element` (`set`) | O(1) | `Array.Small Copyable.swift:29-33` | `Copyable` |
| update(i, x) | **PARTIAL** — `_modify` removed (compiler bug workaround) | — | `Array.Small ~Copyable.swift:86-88` | `~Copyable` |
| append(x) | `mutating func append(_ element: consuming Element)` | O(1) amortized | `Array.Small ~Copyable.swift:115-117` | `~Copyable` |
| insert(i, x) | **MISSING** | — | — | — |
| delete(i) | **MISSING** | — | — | — |
| pop_back() | `mutating func removeLast() -> Element?` | O(1) | `Array.Small ~Copyable.swift:121-124` | `~Copyable` |
| iterate | `makeIterator() -> Array.Small.Iterator` | O(n) | `Array.Small.swift:64-66` | `Copyable` |
| iterate | `.forEach { }` (borrowing via Property.View) | O(n) | `Array.Small ~Copyable.swift:224-233` | `~Copyable` |
| iterate | `.forEach.borrowing { }` | O(n) | `Array.Small ~Copyable.swift:238-240` | `~Copyable` |
| iterate | `.drain { }` (consuming via Property.View) | O(n) | `Array.Small ~Copyable.swift:261-264` | `~Copyable` |
| iterate | `.forEach.consuming { }` | O(n) | `Array.Small Copyable.swift:70-74` | `Copyable` |
| find(x) | **MISSING** (requires `Equatable`) | — | — | — |
| size/count | `var count: Index.Count` | O(1) | `Array.Small ~Copyable.swift:54` | `~Copyable` |
| isEmpty | `var isEmpty: Bool` | O(1) | `Array.Small ~Copyable.swift:58` | `~Copyable` |
| capacity | `var capacity: Index.Count` | O(1) | `Array.Small ~Copyable.swift:62` | `~Copyable` |

**Additional operations (beyond canonical)**:

| Operation | Method/Property | Source File | Constraint |
|-----------|----------------|-------------|------------|
| isSpilled | `var isSpilled: Bool` | `Array.Small ~Copyable.swift:66` | `~Copyable` |
| Safe access | `func element(at index: Index) -> Element?` | `Array.Small Copyable.swift:44-47` | `Copyable` |
| Offset access | `func element(at base: Index, offsetBy offset: Index.Offset) -> Element?` | `Array.Small Copyable.swift:50-57` | `Copyable` |
| Borrow access | `func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R` | `Array.Small ~Copyable.swift:99-102` | `~Copyable` |
| Clear all | `mutating func removeAll(keepingCapacity: Bool = false)` | `Array.Small ~Copyable.swift:128-130` | `~Copyable` |
| Read-only span | `var span: Span<Element>` | `Array.Small ~Copyable.swift:139-145` | `~Copyable` |
| Mutable span | `var mutableSpan: MutableSpan<Element>` | `Array.Small ~Copyable.swift:149-154` | `~Copyable` |
| Unsafe read | `func withUnsafeBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Small ~Copyable.swift:167-175` | `Copyable`, `@_spi(Unsafe)` |
| Unsafe write | `mutating func withUnsafeMutableBufferPointer<R, E>(_:) throws(E) -> R` | `Array.Small ~Copyable.swift:180-189` | `Copyable`, `@_spi(Unsafe)` |
| Indexed navigation | `startIndex`, `endIndex`, `index(after:)`, `index(before:)` | `Array.Small ~Copyable.swift:25-41` | `~Copyable` |

**Protocol conformances**: `Collection.Protocol where Element: Copyable`, `Collection.Access.Random where Element: Copyable`, `Collection.Indexed` (deleted 2026-06), `Collection.Bidirectional`, `Sequence.Protocol where Element: Copyable`, `@unchecked Sendable where Element: Sendable`.

**Note**: Cannot conform to `Swift.Collection` because `Array.Small` is unconditionally `~Copyable`.

**Error type**: `Array.Small.Error` (typealias to `__ArraySmallError`) with cases `.strideExceedsSlotSize(elementStride:maxSlotSize:)` and `.alignmentExceedsStorageAlignment(elementAlignment:maxAlignment:)`.

**Phantom-typed wrapper**: `Array.Small.Indexed<Tag>` with `count`, `isEmpty`, `capacity`, `append(_:)`, `removeLast()`, `removeAll(keepingCapacity:)`, `Sendable where Element: Sendable`. **Note**: subscript is currently missing (comment: "Index.Bounded<N> subscript removed - type not yet implemented in index-primitives").

---

### Variant: Bounded (Array.Bounded\<N\>)

**Storage**: Fixed-count, heap-allocated via `Buffer<Element>.Linear.Bounded`. CoW when `Element: Copyable`. Compile-time dimension with `Algebra.Z<N>` indexing.

| Canonical Operation | Method/Property | Complexity | Source File | Constraint |
|---------------------|----------------|------------|-------------|------------|
| access(i) | **MISSING** — no subscript defined in current source | — | — | — |
| update(i, x) | **MISSING** — no subscript defined in current source | — | — | — |
| append(x) | N/A — fixed-count | — | — | — |
| insert(i, x) | N/A — fixed-count | — | — | — |
| delete(i) | N/A — fixed-count | — | — | — |
| pop_back() | N/A — fixed-count | — | — | — |
| iterate | **MISSING** — no iterator or forEach defined | — | — | — |
| find(x) | **MISSING** (requires `Equatable`) | — | — | — |
| size/count | **MISSING** — no `count` property defined | — | — | — |
| isEmpty | **MISSING** — no `isEmpty` property defined | — | — | — |
| capacity | **Implicit** (compile-time generic parameter `N`) | O(0) | — | — |

**Defined API** (all that exists):

| Operation | Method/Property | Source File |
|-----------|----------------|-------------|
| Type definition | `struct Bounded<let N: Int>: ~Copyable` | `Array.swift:175-185` (Core) |
| Index type | `typealias Index = Algebra.Z<N>` | `Array.Bounded.Index.swift:29` |
| Buffer init | `package init(_buffer: consuming Buffer<Element>.Linear.Bounded)` | `Array.swift:182-184` (Core) |
| Conditional Copyable | `Copyable where Element: Copyable` | `Array.swift:219` (Core) |
| Conditional Sendable | `@unchecked Sendable where Element: Sendable` | `Array.swift:225` (Core) |

**Protocol conformances**: `Copyable where Element: Copyable`, `@unchecked Sendable where Element: Sendable`. No collection or sequence protocol conformances.

**Assessment**: `Array.Bounded` is a **stub**. It has its struct definition, index typealias, and conditional conformances but no usable public API (no subscript, no count, no iteration, no initializer).

---

## Gap Analysis

### Present and Correctly Mapped

| Canonical Operation | Dynamic | Fixed | Static | Small | Bounded |
|---------------------|:-------:|:-----:|:------:|:-----:|:-------:|
| access(i) | Yes | Yes | Yes | Yes | **No** |
| update(i, x) | Yes | Yes | Yes | Partial* | **No** |
| append(x) | Yes | N/A | Yes (throws) | Yes | N/A |
| pop_back() | Yes | N/A | Yes | Yes | N/A |
| iterate | Yes | Yes | Yes | Yes | **No** |
| size/count | Yes | Yes | Yes | Yes | **No** |
| isEmpty | Yes | Yes | Yes | Yes | **No** |
| capacity | Yes | Yes | Implicit | Yes | Implicit |

\* Small variant `_modify` on `~Copyable` subscript is removed due to compiler bug.

### Missing — Should Add (Primitives Layer)

These operations are fundamental to the Array ADT and do not require `Equatable`, `Comparable`, or other higher-layer constraints.

| Operation | Variant(s) | Priority | Rationale |
|-----------|-----------|----------|-----------|
| `insert(at:_:)` | Dynamic | Medium | Position-based insertion is a core SequenceContainer operation. O(n) shift is inherent to contiguous storage. The buffer layer likely already provides `insert(at:)`. |
| `remove(at:)` | Dynamic | Medium | Position-based removal is the complement of insert. Same rationale. |
| `insert(at:_:)` | Static, Small | Low | These could throw on full (Static) or auto-grow (Small). Less urgent than Dynamic. |
| `remove(at:)` | Static, Small | Low | Same as above. |
| `subscript(index:)` | Bounded | **High** | The entire point of Bounded is type-safe indexing via `Algebra.Z<N>`. Without a subscript, the type is unusable. |
| `count` / `isEmpty` | Bounded | **High** | Basic query operations required for any collection. |
| `init(count:initializingWith:)` | Bounded | **High** | Without a public initializer, users cannot create instances. |
| `iterate` | Bounded | **High** | Collection traversal is fundamental. |
| `_modify` on `~Copyable` subscript | Small | Medium | Blocked by Swift compiler bug. Track and restore. |

### Missing — Intentionally Absent (Higher Layer)

These operations require protocol constraints (`Equatable`, `Comparable`, `Hashable`) that belong at Layer 2 (Standards) or Layer 3 (Foundations), not Layer 1 (Primitives).

| Operation | Reason for Absence | Appropriate Layer |
|-----------|--------------------|-------------------|
| `find(x)` / `contains(x)` / `firstIndex(of:)` | Requires `Element: Equatable` | Standards or Foundations |
| `sort()` / `sorted()` | Requires `Element: Comparable` | Standards or Foundations |
| `Equatable` conformance | Requires `Element: Equatable` | Standards (noted in prior audit) |
| `Hashable` conformance | Requires `Element: Hashable` | Standards (noted in prior audit) |
| `Codable` conformance | Requires `Element: Codable`, imports Foundation concepts | Foundations |
| `CustomStringConvertible` | Requires string interpolation of elements | Low priority; cosmetic |
| `map(_:)` returning Array | Available via `Swift.Collection` on Copyable variants | Could be added as convenience |
| Concatenation (`+`) | Monoid structure | Foundations (algebra layer) |

---

## Outcome

**Status**: RECOMMENDATION

### Coverage Summary

| Variant | Canonical Ops Applicable | Ops Present | Coverage |
|---------|:------------------------:|:-----------:|:--------:|
| Dynamic | 9 (all except insert/delete which are medium-priority) | 7 | **78%** |
| Fixed | 5 (access, update, iterate, count, isEmpty) | 5 | **100%** |
| Static | 9 | 7 | **78%** |
| Small | 9 | 7 (update partial) | **~74%** |
| Bounded | 5 | 0 | **0%** |

### Notable Gaps

1. **Array.Bounded is a stub** — highest priority. It defines a struct, index typealias, and conditional conformances, but has zero usable public API. No subscript, no count, no initializer, no iteration. This variant needs to be either completed or explicitly documented as work-in-progress.

2. **No `insert(at:)` / `remove(at:)`** — the two shift-based operations from the canonical ADT are absent from all variable-count variants (Dynamic, Static, Small). These are O(n) but fundamental to the SequenceContainer concept. Medium priority for Dynamic; low priority for Static/Small.

3. **Small `_modify` disabled** — the `~Copyable` subscript on `Array.Small` cannot provide `_modify` access due to a Swift compiler crash (`DiagnoseStaticExclusivity`). This means `~Copyable` elements in a Small array cannot be mutated in-place. This is a compiler-blocked gap, not a design gap.

### Action Items

| Priority | Action |
|----------|--------|
| **High** | Complete `Array.Bounded<N>`: add subscript, count, isEmpty, initializer, iteration. |
| **Medium** | Add `insert(at:_:)` and `remove(at:)` to `Array.Dynamic`. |
| **Medium** | Track Swift compiler bug for Small `_modify` and restore when fixed. |
| **Low** | Add `insert(at:_:)` and `remove(at:)` to Static and Small variants. |
| **Low** | Consider wrapping `Array.Static.Iterator` (currently exposes buffer iterator type directly — noted in prior audit). |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms for Array
- Stepanov & McJones, "Elements of Programming" (2009): SequenceContainer concept
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md` — prior layering audit
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/` — all source files inventoried 2026-02-16
