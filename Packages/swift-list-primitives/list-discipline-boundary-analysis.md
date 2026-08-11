# List Discipline Boundary Analysis

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

`list-primitives` sits at the top of this chain, wrapping `Buffer.Linked` (and its variants) to present a consumer-facing linked list abstraction. The question: does `list-primitives` contain ONLY list-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-list-primitives).

## Question

What semantics belong SOLELY to the list abstraction layer, and does `list-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Abstract Data Type Theory (Liskov & Guttag; Classical ADT)

The formal ADT specification for List:

```
Sorts: List, Element, Bool

Operations:
  nil       : -> List
  cons      : Element x List -> List
  head      : List -> Element
  tail      : List -> List
  isEmpty   : List -> Bool

Axioms:
  head(cons(e, l)) = e                   (head-after-cons)
  tail(cons(e, l)) = l                   (tail-after-cons)
  isEmpty(nil)     = true                (nil is empty)
  isEmpty(cons(e, l)) = false            (cons is non-empty)
```

The ADT mentions NO implementation concerns: no nodes, no pointers, no arenas, no contiguous memory. The list is purely the **recursive cons/head/tail contract**. Unlike the array ADT (which is indexed), the list ADT provides only sequential access through destructuring.

Key distinction from Array ADT: the list is *inductively defined* (built from nil + cons), while the array is *indexed* (get/set by position). The list has no `get(i)` operation in its fundamental specification.

### Source 2: Haskell -- List as Fundamental Algebraic Type

Haskell's list is the canonical algebraic data type:

```haskell
data [] a = [] | a : [a]
-- equivalently:
data List a = Nil | Cons a (List a)
```

The list is a sum type with two variants: empty (`Nil`) and non-empty (`Cons x xs`). This makes it:

- **Functor**: `fmap f [] = []; fmap f (x:xs) = f x : fmap f xs` -- structure-preserving transformation
- **Applicative**: `pure x = [x]`; `fs <*> xs = [f x | f <- fs, x <- xs]`
- **Monad**: `xs >>= f = concatMap f xs` -- the "nondeterminism" monad
- **Foldable/Traversable**: `foldr`, `foldl`, effectful traversal preserving shape
- **Monoid under concatenation**: `[] ++ xs = xs; xs ++ [] = xs` (identity is `[]`)
- **Semigroup**: `(xs ++ ys) ++ zs = xs ++ (ys ++ zs)` (associative)

Key insight: Haskell lists are *cons lists* (singly-linked). Pattern matching (`case xs of { [] -> ...; (x:xs) -> ... }`) is the only access method. There is no `O(1)` indexed access -- `(!!) :: [a] -> Int -> a` is `O(n)`.

The algebraic structure (Functor, Monad, Monoid) is *solely list-discipline*. It depends only on the cons/nil structure, not on any storage mechanism.

### Source 3: C++ STL -- `std::list` and `std::forward_list` (Stepanov)

C++ provides the clearest separation between singly-linked (`std::forward_list`) and doubly-linked (`std::list`) semantics:

**`std::forward_list`** (singly-linked):
- ForwardIterator only (no `--`, no `rbegin/rend`)
- `push_front`, `pop_front` -- O(1) front-only modification
- `insert_after`, `erase_after` -- position-relative mutation (not `insert_before`)
- `splice_after` -- constant-time transfer of nodes between lists
- `merge`, `sort`, `unique`, `remove`, `reverse` -- member functions (not free algorithms) because they exploit node relinking

**`std::list`** (doubly-linked):
- BidirectionalIterator (`++` and `--`, but NOT RandomAccessIterator)
- `push_front`, `push_back`, `pop_front`, `pop_back` -- O(1) both ends
- `insert`, `erase` -- position-based O(1) given iterator
- `splice` -- constant-time node transfer (the signature list operation)
- `merge`, `sort`, `unique`, `remove`, `reverse` -- same member functions
- **Iterator stability**: adding, removing, and moving elements does NOT invalidate other iterators or references. An iterator is invalidated only when its element is deleted.

**Key list-unique semantics from STL**:
1. **Splice**: O(1) transfer of nodes between lists (impossible for arrays)
2. **Iterator stability**: mutations don't invalidate unrelated iterators
3. **Position-relative insertion**: `insert_after` (singly) vs `insert` (doubly)
4. **In-place stable sort**: O(n log n) merge sort via node relinking, O(1) extra space
5. **No random access**: deliberately omits `operator[]`

### Source 4: Rust `LinkedList<T>` and Cursor API (RFC 2570)

Rust's `LinkedList` provides the modern systems-programming perspective:

**Core operations**: `push_front`, `push_back`, `pop_front`, `pop_back`, `front`, `back`, `len`, `is_empty`, `clear`, `append` (splice entire other list), `split_off` (split at index).

**Cursor API** (RFC 2570, stabilized):
- `Cursor` / `CursorMut` -- a "finger" pointing between two elements
- Logically circular with a "ghost" non-element between tail and head
- `move_next()`, `move_prev()` -- O(1) navigation
- `CursorMut::insert_before`, `insert_after` -- O(1) insertion at cursor position
- `CursorMut::remove_current` -- O(1) deletion
- `CursorMut::splice_before`, `splice_after` -- O(1) list-to-list transfer
- `CursorMut::split_before`, `split_after` -- O(1) list splitting

**Key insight**: Rust explicitly states that cursors are *specific to linked lists*. "In other collections such as Vec, a cursor does not make sense." The cursor/splice interface is the defining feature that makes a linked list a linked list at the API level.

**What LinkedList does NOT provide**: `Index` trait (no `list[i]`), `Deref<Target=[T]>` (no slice coercion). This is deliberate -- linked lists are not random-access.

### Source 5: What Makes a List a List (vs Array-Backed Sequence)

Synthesizing across all sources, the essential semantic properties of a linked list are:

| Property | List | Array |
|----------|------|-------|
| **Access pattern** | Sequential (head/tail destructuring) | Indexed (O(1) random access) |
| **Fundamental operation** | cons (prepend) | set/get by index |
| **Insertion complexity** | O(1) at known position | O(n) (shifting required) |
| **Memory layout** | Non-contiguous (nodes + links) | Contiguous |
| **Iterator stability** | Preserved across mutations | Invalidated by insertions |
| **Splice** | O(1) node transfer | O(n) element copying |
| **Algebraic identity** | Recursive sum type (Nil + Cons) | Indexed product (i -> a) |
| **Protocol hierarchy** | ForwardIterator/BidirectionalIterator | RandomAccessIterator |

The defining boundary: a list commits to **sequential access with O(1) positional mutation** and refuses to offer indexed access. An array commits to **indexed access with density invariant** and pays O(n) for positional mutation.

---

## Analysis

### What is SOLELY List Discipline

#### A. Structural Topology (Singly vs Doubly Linked)

The list's primary contribution that no lower layer provides: the **link-count parameterization** that determines traversal and mutation semantics.

| Semantic | What it provides | Why not in Buffer |
|----------|-----------------|-------------------|
| `Linked<1>` (singly-linked) | Forward-only traversal, O(1) prepend, O(n) popLast | Buffer.Linked provides the node pool; List names the discipline |
| `Linked<2>` (doubly-linked) | Bidirectional traversal, O(1) at both ends | Same |
| `N >= 2` precondition on `reversed` | Enforces that reverse traversal requires backward links | This is a *semantic guarantee* the list makes to consumers |
| Complexity table documentation | O(1) vs O(n) per operation per link count | The buffer has no obligation to document user-facing complexity contracts |

#### B. Consumer-Facing Operations (cons/head/tail discipline)

| Operation | ADT Mapping | What it provides |
|-----------|-------------|-----------------|
| `prepend(_:)` | cons | Adds element at head -- the canonical list operation |
| `append(_:)` | snoc (cons at tail) | Adds element at tail, with documented complexity difference by N |
| `popFirst()` | head + tail (destructuring) | Removes and returns head |
| `popLast()` | last + init (destructuring) | Removes and returns tail |
| `removeFirst()` | head + tail with typed throw | Safe destructuring with error discipline |
| `removeLast()` | last + init with typed throw | Same |
| `first` / `last` (Copyable) | head / last observers | Non-destructive observation |
| `peek.first` / `peek.last` | head / last with borrowing | ~Copyable-safe observation via closure |

#### C. Protocol/Interface Conformance

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `Sequence.Iterator.Protocol` / `IteratorProtocol` | Multi-pass sequential traversal contract | Buffer disciplines vary; only List commits to the Sequence contract |
| `Swift.Sequence` | Interop with all stdlib `for-in` and higher-order methods | Buffer should not carry stdlib coupling |
| `Equatable where Element: Equatable` | Element-wise, structure-independent equality | The buffer has no obligation to define equality semantics |
| `Hashable where Element: Hashable` | Consistent hashing for use as dictionary keys | Same |
| `List.Linked.Iterator` / `List.Linked.Bounded.Iterator` | Wrapped buffer iterator with list-level type identity | Provides type-level encapsulation |

#### D. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **Ordering preservation** | Elements maintain insertion order; prepend goes to front, append goes to back |
| **Value semantics commitment** | Buffer provides CoW *mechanism*; list commits to `var b = a; b.prepend(x)` not affecting `a` |
| **Capacity independence of identity** | Two lists with the same elements in the same order are equal regardless of internal pool capacity |
| **Sequential-only access** | List deliberately does NOT offer `subscript(Index)` -- this is a *semantic refusal*, not a missing feature |
| **Typed error discipline** | `.empty`, `.overflow`, `.invalidCapacity` as typed throws -- the list owns the error semantics |
| **`keepingCapacity` parameter** | `clear(keepingCapacity:)` is consumer ergonomics; buffer's `removeAll` always keeps capacity |

#### E. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `List.Linked<N>` -- link-count parameterized | The generic `N` parameter is purely a list-discipline choice; the buffer also has `<N>` but the *semantic meaning* (singly vs doubly linked) is the list's contribution |
| `List.Linked.Bounded` -- fixed-capacity with overflow error | Promise to the user: "this has a hard capacity limit and will throw on overflow" |
| `List.Linked.Inline<capacity>` -- inline commitment | Promise: "this never heap-allocates" |
| `List.Linked.Small<inlineCapacity>` -- inline + spill | Promise: "inline storage with automatic spill to heap" |
| Conditional `Copyable` | `Copyable where Element: Copyable` as a user-facing guarantee |
| Conditional `Sendable` | `@unchecked Sendable where Element: Sendable` |
| Unconditional `~Copyable` for Inline/Small | Inline and Small are always move-only due to `@_rawLayout` -- this is a type-level commitment |

#### F. Variant Taxonomy and Namespace

| Feature | What it adds |
|---------|-------------|
| `List<Element>` namespace | Top-level generic enum organizing the family |
| `List.Linked<N>` | Dynamic linked list |
| `List.Linked.Bounded` | Fixed-capacity variant |
| `List.Linked.Inline<capacity>` | Zero-allocation variant |
| `List.Linked.Small<inlineCapacity>` | Small-buffer optimization variant |
| `List.Index` (typealias to `Index<Element>`) | Type-safe index preventing cross-collection confusion |
| Variant-specific error types | `List.Linked.Error`, `Bounded.Error`, `Inline.Error`, `Small.Error` |

#### G. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Property.View patterns (`peek`, `reversed`) | Namespace-scoped access using `Property<Tag, Self>.View.Read` |
| `forEach(_:)` on all variants | Borrowing iteration for ~Copyable elements |
| `forEachReversed(_:)` on Inline/Small | Direct reverse traversal |
| `reversed.forEach` on Linked/Bounded | Property.View-based reverse traversal |
| CoW-safe Copyable overloads | Separate `prepend`/`append`/`popFirst`/`popLast`/`clear` for Copyable elements with `ensureUnique()` |
| Hoisted error types with typealiases | `__ListLinkedError` hoisted to module level, exposed as `List.Linked.Error` |
| `Peek` / `Reversed` tag enums | [PATTERN-022] compliant Property.View discriminators |

#### H. Algebraic Structure (not yet implemented but canonically List's)

| Property | List owns it |
|----------|-------------|
| Functor (`map`) | Structure-preserving transformation (cons structure maintained) |
| Foldable (`reduce`/`fold`) | Collapse to summary value following cons order |
| Traversable | Effectful transformation preserving list shape |
| Monad (`flatMap`/`concatMap`) | The "nondeterminism" monad -- unique to lists among standard collections |
| Monoid under `++` | Concatenation with `[]` as identity |

### What Buffer.Linked Owns (List Merely Delegates)

| Concern | Owned by Buffer.Linked |
|---------|----------------------|
| Arena allocation/deallocation | Creates/destroys node pool storage |
| Node pool management | Free list, slot allocation/deallocation |
| Capacity tracking | Pool capacity |
| Count tracking | Number of active nodes |
| Growth policy | Pool resizing when arena is full |
| CoW mechanism | `ensureUnique()` (reference counting) |
| Element init/move/deinit lifecycle | Via node slots in the arena |
| Link maintenance | `next`/`prev` indices within nodes |
| Head/tail pointer tracking | Internal pointers to first/last active nodes |
| `insert.front` / `insert.back` | Node allocation + link wiring |
| `remove.front` / `remove.back` | Node deallocation + link rewiring |
| `peekFront` / `peekBack` | Borrowing access to node element |
| `forEach` / `forEachReversed` | Link-following traversal |
| `makeIterator()` | Buffer-level iterator following links |
| `first` / `last` properties | Accessing head/tail node elements |
| Equatable/Hashable implementation | Element-wise comparison following link order |
| `removeAll()` | Bulk deinitialization of all nodes |
| Inline storage (`@_rawLayout`) | Stack-allocated node arena for Inline/Small variants |
| Spill detection (`isSpilled`) | Small variant's inline-vs-heap tracking |

---

## Audit: Current list-primitives

### Audit Methodology

For each file in `list-primitives`, classify every public API member as:
- **LIST**: Solely list discipline (semantic contract, type invariant, protocol conformance, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer

### Module Structure

```
List Primitives Core/
  List.swift                        -- List<Element> namespace
  List.Index.swift                  -- List.Index typealias
  List.Linked.swift                 -- List.Linked<N> struct + variants (Bounded, Inline, Small)
  List.Linked.Error.swift           -- Error types (hoisted + typealiased)
  exports.swift                     -- Re-exports

List Linked Primitives/
  List.Linked ~Copyable.swift       -- Core ~Copyable operations + peek + forEach + reversed
  List.Linked Copyable.swift        -- CoW-safe overloads + first/last + Sequence + Equatable + Hashable
  List.Linked.Bounded.swift         -- Bounded variant: all operations + peek + forEach + Sequence + Equatable + Hashable
  List.Linked.Inline.swift          -- Inline variant: all operations + peek + forEach
  List.Linked.Small.swift           -- Small variant: all operations + peek + forEach
  exports.swift                     -- Re-exports

List Primitives/
  exports.swift                     -- Umbrella re-export
```

### Findings

#### Pure List Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `List<Element>` namespace enum | Architecture | `List.swift` |
| `List.Index` typealias to `Index<Element>` | Type safety | `List.Index.swift` |
| `List.Linked<N>` struct declaration with `N` parameter | Topology | `List.Linked.swift` |
| `List.Linked.Bounded` struct with `capacity` property | Type invariant | `List.Linked.swift` |
| `List.Linked.Inline<capacity>` struct | Type invariant | `List.Linked.swift` |
| `List.Linked.Small<inlineCapacity>` struct | Type invariant | `List.Linked.swift` |
| `N >= 1 && N <= 2` precondition in `init()` | Semantic guard | `List.Linked.swift` |
| `Bounded.init(capacity:) throws(__ListLinkedBoundedError)` | Typed throws | `List.Linked.swift` |
| `init(reservingCapacity:) throws(Error)` | Typed throws | `List.Linked.swift` |
| Conditional `Copyable where Element: Copyable` | Type invariant | `List.Linked.swift` |
| `@unchecked Sendable where Element: Sendable` | Type invariant | `List.Linked.swift` |
| `__ListLinkedError` / `__ListLinkedBoundedError` / `__ListLinkedInlineError` / `__ListLinkedSmallError` | Error discipline | `List.Linked.Error.swift` |
| Error typealiases (`List.Linked.Error`, etc.) | Nest.Name API | `List.Linked.Error.swift` |
| `prepend(_:)` naming (list-specific term) | Naming | `List.Linked ~Copyable.swift`, all variants |
| `removeFirst() throws(Error)` | Typed throws + safety | `List.Linked ~Copyable.swift`, all variants |
| `removeLast() throws(Error)` | Typed throws + safety | `List.Linked ~Copyable.swift`, all variants |
| `clear(keepingCapacity:)` with boolean parameter | Ergonomics | `List.Linked ~Copyable.swift`, `List.Linked Copyable.swift` |
| `peek.first` / `peek.last` via Property.View | ~Copyable access | `List.Linked ~Copyable.swift`, `List.Linked.Bounded.swift` |
| `Peek` / `Reversed` tag enums | [PATTERN-022] | `List.Linked.swift` |
| `reversed.forEach` via Property.View | Directional traversal | `List.Linked ~Copyable.swift`, `List.Linked.Bounded.swift` |
| `N >= 2` precondition on `reversed` | Semantic guard | `List.Linked ~Copyable.swift`, `List.Linked.Bounded.swift` |
| Bounded overflow guard (`guard !isFull else { throw .overflow }`) | Capacity enforcement | `List.Linked.Bounded.swift` |
| Inline overflow catch-and-rethrow as `.overflow` | Error translation | `List.Linked.Inline.swift` |
| `List.Linked.Iterator` wrapping `Buffer.Linked.Iterator` | Type identity | `List.Linked Copyable.swift` |
| `List.Linked.Bounded.Iterator` wrapping `Buffer.Linked.Iterator` | Type identity | `List.Linked.Bounded.swift` |
| `Sequence.Iterator.Protocol` / `IteratorProtocol` conformance | Protocol | `List.Linked Copyable.swift`, `List.Linked.Bounded.swift` |
| `Swift.Sequence` conformance + `makeIterator()` | Protocol | `List.Linked Copyable.swift`, `List.Linked.Bounded.swift` |
| `Equatable where Element: Equatable` | Algebraic | `List.Linked Copyable.swift`, `List.Linked.Bounded.swift` |
| `Hashable where Element: Hashable` | Algebraic | `List.Linked Copyable.swift`, `List.Linked.Bounded.swift` |
| CoW-safe Copyable overloads (calling `ensureUnique()` before mutation) | Value semantics | `List.Linked Copyable.swift`, `List.Linked.Bounded.swift` |
| `Inline.init()` / `Small.init()` | Construction | `List.Linked.Inline.swift`, `List.Linked.Small.swift` |
| `@_exported` re-exports in `exports.swift` files | Module structure | All `exports.swift` |
| Note: "does not support O(1) indexed subscript access" | Semantic refusal | `List.Index.swift` |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `_buffer.count` | Buffer.Linked | **OK** -- List surface for buffer state |
| `var isEmpty` -> `_buffer.isEmpty` | Buffer.Linked | **OK** |
| `var capacity` -> `_buffer.capacity` | Buffer.Linked | **OK** |
| `var isFull` -> `_buffer.isFull` | Buffer.Linked | **OK** |
| `prepend(_:)` -> `_buffer.insert.front(_:)` | Buffer.Linked | **OK** -- List names the operation `prepend`; buffer uses `insert.front` |
| `append(_:)` -> `_buffer.insert.back(_:)` | Buffer.Linked | **OK** -- List names the operation `append`; buffer uses `insert.back` |
| `popFirst()` -> `_buffer.remove.front()` | Buffer.Linked | **OK** -- List names `popFirst`; buffer uses `remove.front` |
| `popLast()` -> `_buffer.remove.back()` | Buffer.Linked | **OK** -- List names `popLast`; buffer uses `remove.back` |
| `clear()` -> `_buffer.removeAll()` | Buffer.Linked | **OK** -- List adds `keepingCapacity` parameter |
| `first` -> `_buffer.first` | Buffer.Linked | **OK** |
| `last` -> `_buffer.last` | Buffer.Linked | **OK** |
| `forEach(_:)` -> `_buffer.forEach(_:)` | Buffer.Linked | **OK** |
| `forEachReversed(_:)` -> `_buffer.forEachReversed(_:)` | Buffer.Linked | **OK** |
| `peekFirst(_:)` -> `_buffer.peekFront(_:)` | Buffer.Linked | **OK** |
| `peekLast(_:)` -> `_buffer.peekBack(_:)` | Buffer.Linked | **OK** |
| `reserve(_:)` -> `_buffer.ensureCapacity(_:)` | Buffer.Linked | **OK** -- List names it `reserve`; buffer uses `ensureCapacity` |
| `makeIterator()` -> wraps `_buffer.makeIterator()` | Buffer.Linked | **OK** |
| `== (lhs, rhs)` -> `lhs._buffer == rhs._buffer` | Buffer.Linked | **OK** -- List owns the semantic; buffer provides the implementation |
| `hash(into:)` -> `_buffer.hash(into:)` | Buffer.Linked | **OK** |
| `isSpilled` -> `_buffer.isSpilled` | Buffer.Linked.Small | **CONTESTED** (see below) |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `List.Linked.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** -- a user reasonably wants to know if they've spilled. This is a valid consumer-facing diagnostic property. The SmallVec/SmallList pattern's value proposition depends on knowing when you've spilled. Keep it, but acknowledge it leaks buffer abstraction. |
| `ensureCapacityForOneMore()` on `List.Linked` | Internal `package` method that calls `_buffer.ensureCapacity`. Not public. | **OK** -- implementation detail correctly scoped as `package`. |
| `Bounded.ensureUnique()` on Copyable extension | Internal `@usableFromInline` method that calls `_buffer.ensureUnique()`. | **OK** -- CoW mechanism delegation, correctly encapsulated. Not public API. |
| Naming asymmetry: `peek.first/peek.last` (Linked/Bounded) vs `peekFirst/peekLast` (Inline/Small) | Linked and Bounded use Property.View pattern; Inline and Small use direct methods. | **MINOR** -- inconsistency in access patterns across variants. The Property.View pattern is more consistent with the Swift Institute style, but Inline/Small's simpler approach is valid for unconditionally ~Copyable types. |
| `forEach` overload for Copyable elements (Inline/Small) | Separate `forEach(_ body: (Element) -> Void)` overload for Copyable elements alongside the borrowing version. | **OK** -- consumer ergonomics. Copyable elements don't need the `borrowing` qualifier, and providing a simpler closure signature is user-friendly. |
| Bounded calls `ensureUnique()` before every mutation | CoW uniqueness check happens at the list layer for Bounded, not in the buffer. | **CONTESTED** -- in the dynamic `List.Linked`, the Copyable overloads also call `_buffer.insert.front` which presumably handles CoW internally. But `Bounded` explicitly calls `ensureUnique()` at the list layer before delegating. This is a slight inconsistency in *where* CoW is enforced. However, since Bounded has an overflow guard (`guard !isFull`) that must happen before buffer access, interleaving uniqueness check here is pragmatically correct. |
| `Inline.init()` is the only construction path | Inline does not have `init(reservingCapacity:)` since its capacity is compile-time. | **OK** -- this is correct list-discipline. Inline's capacity is a type parameter, not a runtime value. |

### What's MISSING from List (things that are solely list discipline but not yet present)

| Missing | Category | Priority | Rationale |
|---------|----------|----------|-----------|
| Cursor / position-based mutation | Core list semantics | **High** | The defining list operation per STL and Rust. O(1) insert/remove at a known position is what justifies using a list over an array. Without cursors, the list is just a deque. |
| `splice` / `append(contentsOf:)` | Core list semantics | **High** | O(1) transfer of nodes between lists. This is the signature operation that only linked lists can do in constant time. |
| `split(at:)` | Core list semantics | **Medium** | O(1) splitting of a list at a cursor position into two lists. |
| `map(_:)` returning `List.Linked` | Functor | **Medium** | Structure-preserving transformation. Stdlib's `Sequence.map` returns `Array`, not `List`. |
| `flatMap(_:)` / `concatMap` | Monad | **Low** | The list monad. Unique algebraic structure among standard collections. |
| `reduce`/`fold` (non-Sequence) | Foldable | **Low** | For ~Copyable variants that can't conform to Sequence. |
| Concatenation (`+` operator) | Monoid | **Low** | List concatenation with `[]` as identity. |
| `reversed()` returning `List.Linked` (for N==2) | List operation | **Low** | In-place O(n) reversal by relinking, not copying. |
| `sort()` / `sorted()` member (merge sort) | List-specific algorithm | **Low** | O(n log n) merge sort with O(1) extra space via node relinking. This is canonically a list member function in STL because it exploits list structure. |
| `contains(where:)` for ~Copyable | Sequential search | **Low** | Sequence provides this for Copyable; ~Copyable variants need their own. |
| `CustomStringConvertible` / `CustomDebugStringConvertible` | Ergonomics | **Low** | Debug printing. |
| `ExpressibleByArrayLiteral` | Syntax sugar | **Low** | `let list: List<Int>.Linked<2> = [1, 2, 3]` |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: list-primitives is well-layered

The current `list-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Semantic contract** -- cons/head/tail naming, typed throws, complexity guarantees, sequential-only access commitment
2. **Protocol conformance** -- Sequence, Equatable, Hashable, Copyable, Sendable
3. **Type-level invariant** -- Bounded capacity, Inline stack allocation, Small spill behavior, link-count parameterization
4. **Pure delegation** -- thin wrappers that rename buffer operations to list vocabulary (`prepend` vs `insert.front`, `popFirst` vs `remove.front`)

### Specific Recommendations

#### 1. Add Cursor API (High Priority)

The cursor/splice interface is the **defining feature** that separates a linked list from a deque or sequence. Without it, `List.Linked` is functionally a double-ended queue that happens to use nodes internally. Per both C++ STL and Rust RFC 2570, the cursor provides:

- O(1) insert/remove at any position (given cursor)
- O(1) splice (node transfer between lists)
- O(1) split (list division at cursor)
- Iterator stability guarantees

This is solely list-discipline and cannot exist at the buffer layer because it requires list-level semantic contracts about iterator validity and ownership transfer.

#### 2. Add `splice` / `split` (High Priority)

Even without a full cursor API, `splice` (transfer all nodes from one list to another) and `split(at:)` are signature list operations. They are O(1) for linked lists and O(n) for arrays -- this is the fundamental justification for choosing a list.

#### 3. `isSpilled` is acceptable (same verdict as Array.Small)

`List.Linked.Small.isSpilled` exposes a buffer detail, but it's a *diagnostic* property that users legitimately need. The SmallList pattern's value proposition depends on knowing when you've spilled. Keep it.

#### 4. Consider unifying peek patterns across variants (Minor)

`List.Linked` and `List.Linked.Bounded` use `peek.first { }` / `peek.last { }` via Property.View, while `Inline` and `Small` use `peekFirst { }` / `peekLast { }` as direct methods. For consistency, consider aligning these. However, both approaches are valid and this is cosmetic, not architectural.

#### 5. No buffer concerns have leaked upward

The audit found **zero instances** of list-primitives doing work that properly belongs to the buffer layer. All node pool management, arena allocation, link maintenance, growth policy, and element lifecycle operations are handled by `Buffer.Linked` and its variants. The `_buffer` stored property is the only coupling, and it's correctly `package`-scoped.

#### 6. The "sequential-only access" commitment is correctly maintained

Unlike array-primitives (which provides `subscript` with bounds checking), list-primitives deliberately does NOT offer indexed subscript access. The comment in `List.Index.swift` explicitly states: "Linked lists do not support O(1) indexed access." This is a correct *semantic refusal* -- the list's `Index` typealias exists for count/offset arithmetic, not for random element access.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure list discipline | 35+ distinct APIs | Correctly placed |
| Pure delegation | 18 passthrough properties/methods | Correctly placed -- thin wrapping with list-vocabulary naming is the design intent |
| Buffer concern leaked into list | **0** | Clean separation |
| List concern missing | 8-12 items | Future work (especially cursor/splice), not a layering violation |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": List ADT axioms (cons/head/tail)
- [List (abstract data type) -- Wikipedia](https://en.wikipedia.org/wiki/List_(abstract_data_type))
- [Linked list -- Wikipedia](https://en.wikipedia.org/wiki/Linked_list)
- Haskell `Data.List`, HaskellWiki: [Algebraic Data Types](https://wiki.haskell.org/Algebraic_data_type), [The List Monad](https://www.schoolofhaskell.com/school/starting-with-haskell/basics-of-haskell/13-the-list-monad)
- C++ STL: [std::list](https://en.cppreference.com/w/cpp/container/list.html), [std::forward_list](https://en.cppreference.com/w/cpp/container/forward_list.html)
- Rust: [LinkedList](https://doc.rust-lang.org/std/collections/struct.LinkedList.html), [RFC 2570 -- Linked List Cursors](https://rust-lang.github.io/rfcs/2570-linked-list-cursors.html)
- [Learning Rust With Entirely Too Many Linked Lists -- Cursors](https://rust-unofficial.github.io/too-many-lists/sixth-cursors-intro.html)
- Stepanov & McJones, "Elements of Programming" (2009): coordinate structures and iterator hierarchy
- [Linked Lists vs. Arrays -- AlgoCademy](https://algocademy.com/blog/linked-lists-vs-arrays-when-and-why-to-use-each-data-structure/)
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`
