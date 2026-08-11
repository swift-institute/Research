# Tree Discipline Boundary Analysis

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

`tree-primitives` sits at the top of this chain, wrapping `Buffer<Node>.Arena` (and its variants) to present a consumer-facing tree abstraction. The question: does `tree-primitives` contain ONLY tree-discipline semantics, or has buffer/arena-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-tree-primitives).

## Question

What semantics belong SOLELY to the tree abstraction layer, and does `tree-primitives` currently contain anything that properly belongs to the buffer/arena layer?

---

## Prior Art Survey

### Source 1: Formal ADT Definition (Liskov & Guttag / Tree ADT Theory)

The formal ADT specification for Tree:

```
Types: Tree, Node, Element, Position, Forest

Operations: empty(), insert(t,e,pos), remove(t,pos), root(t),
            parent(t,pos), children(t,pos), isLeaf(t,pos),
            isRoot(t,pos), height(t), size(t)

Axioms:
  root(insert(empty(), e, .root)) = pos_root           (root insertion)
  parent(insert(t, e, .child(p,s)), pos_new) = p       (parent of inserted child)
  isLeaf(insert(t, e, .child(p,s))) = true              (new node is leaf)
  children(t, pos) is empty iff isLeaf(t, pos)         (leaf definition)
  size(insert(t, e, pos)) = size(t) + 1                (insert increments size)
  size(remove(t, pos)) = size(t) - 1 where isLeaf(pos) (remove leaf decrements)
  height(empty()) = -1                                  (empty tree height)
  height(single-node) = 0                              (root-only height)
```

The ADT mentions NO implementation concerns: no arena, no slab, no contiguous memory, no capacity, no generation tokens, no free lists. The tree is purely the **hierarchical parent-child relationship with structural navigation and traversal laws**.

### Source 2: Haskell `Data.Tree` (Rose Trees)

Haskell defines the rose tree algebraically:

```haskell
data Tree a = Node { rootLabel :: a, subForest :: [Tree a] }
type Forest a = [Tree a]
```

This is a lazy, possibly infinite, multi-way tree with arbitrary and internally varying branching factor. Key observations:

- **Functor**: `fmap` preserves tree shape, transforms labels
- **Foldable/Traversable**: collapse and effectful traversal preserving hierarchical structure
- **Traversal orders**: pre-order, post-order, level-order, in-order (binary) defined as tree-discipline operations via the `tree-traversals` package
- **`unfoldTree`/`unfoldForest`**: Construction from seed functions (depth-first and breadth-first variants)
- **No allocation concern**: The tree type captures only structure (node + subforest), not memory layout

### Source 3: Rust `BTreeMap` and `btree-slab` Ecosystem

Rust provides the clearest separation between tree structure and arena storage:

- **`std::collections::BTreeMap`**: B-tree with nodes containing B-1 to 2B-1 elements in contiguous arrays. The tree *discipline* is the B-tree invariant (balanced, ordered keys, node split/merge). The *storage* is internal node arrays with allocator coupling.
- **`btree-slab` crate**: BTreeMap and BTreeSet implementations where every node is allocated in a slab (contiguous memory region), reducing allocations. The slab is the arena; the tree is the structural invariant layered on top.
- **`btree-plus-store` crate**: Combines arena allocation (allocating in large fixed-sized regions) with slab allocation (maintaining linked lists of allocated/discarded nodes). The tree structure and the node storage are explicitly separated by the `BTreeStore` type.

**Key**: The Rust ecosystem demonstrates that "slab/arena = allocation strategy" and "tree = structural invariant" are orthogonal concerns. `btree-slab` parameterizes the tree over its allocator, making this separation explicit.

### Source 4: C++ STL `std::set`/`std::map` (Red-Black Tree)

Stepanov's STL uses red-black trees for ordered associative containers:

- **Tree discipline**: Red-black coloring invariant (root is black, no two consecutive reds, equal black-height on all paths), BST ordering invariant, rotation/recoloring on insert/remove.
- **Node allocation**: Individual per-node allocation with optional free-list reuse (`get_node`/`put_node`). Some implementations embed a sentinel/header node; others allocate it separately.
- **Iterator invalidation**: The *tree* owns the guarantee that iterators remain valid after insert (unlike vector). This is a tree-discipline semantic, not an allocation concern.

Alexander Stepanov noted he would use B*-trees instead of red-black trees if redesigning STL, for cache friendliness -- further evidence that the tree invariant is separate from the node layout strategy.

### Source 5: Tree Traversal Theory

Tree traversal orders are SOLELY tree discipline:

- **Pre-order** (NLR): Visit root, then children left-to-right. Defined recursively by the parent-child structure.
- **Post-order** (LRN): Visit children left-to-right, then root. The natural order for deletion (children before parent).
- **In-order** (LNR): Left subtree, root, right subtree. ONLY meaningful for binary trees (n == 2). Produces sorted output for BSTs.
- **Level-order** (BFS): Visit all nodes at depth d before depth d+1. Requires a queue; defined by the depth metric of the tree.

These traversal orders are mathematical properties of the tree's hierarchical structure. They exist independently of how nodes are stored in memory. An arena-based tree, a pointer-based tree, and a purely functional tree all support the same traversal orders.

### Source 6: Separation Logic (Reynolds, et al.)

Formal verification research explicitly separates:

1. **Shape** -- the node structure (parent-child links, tree connectivity invariant)
2. **Data** -- the payload attached to each node
3. **Memory** -- the heap representation and allocation strategy

"Tree view predicates" in separation logic define the structural invariant independently of the memory representation. This mirrors the Swift Institute's layering: Buffer.Arena owns the memory/allocation, Tree owns the shape/structural invariant.

---

## Analysis

### What is SOLELY Tree Discipline

#### A. Structural Invariant (Parent-Child Hierarchy)

The tree's primary contribution: maintaining the **hierarchical parent-child invariant** on top of flat arena storage. The arena provides a slab of slots; the tree provides the structural wiring.

| Invariant | What it provides | Why not in Buffer/Arena |
|-----------|-----------------|------------------------|
| **Single root** | Exactly 0 or 1 root node | Arena has no concept of "root" -- it is a flat collection of slots |
| **Parent-child links** | Each non-root node has exactly one parent | Arena stores elements independently; inter-element relationships are tree-discipline |
| **Acyclicity** | No node is its own ancestor | Arena permits arbitrary cross-references; the tree forbids cycles |
| **Leaf definition** | A node with no children | Arena has no concept of "children" |
| **Sparse child slots** (N-ary) | `childIndices[0..<n]` with holes permitted | The InlineArray storage is a mechanism; the sparse-slot *semantics* are tree-discipline |
| **Dynamic children** (Unbounded) | Ordered list of children per node | Arena stores flat elements; the child-list ordering is tree-discipline |

#### B. Navigation Operations

| Operation | What it provides | Why not in Buffer/Arena |
|-----------|-----------------|------------------------|
| `root` | Entry point to the hierarchy | Arena has no distinguished element |
| `parent(of:)` | Navigate up the hierarchy | Arena has no "up" |
| `child(of:slot:)` / `child(of:at:)` | Navigate down to a specific child | Arena has no "down" or slot-based children |
| `left(of:)` / `right(of:)` | Binary tree convenience navigation | Binary tree semantics (n == 2) |
| `leftmostChild(of:)` / `rightmostChild(of:)` | Navigate to extreme children | Requires child ordering -- tree-discipline |
| `firstChild(of:)` / `lastChild(of:)` | Unbounded tree child navigation | Requires dynamic child list -- tree-discipline |
| `isLeaf(_:)` | Query hierarchical property | Arena has no leaf concept |
| `childCount(of:)` | Count occupied child slots | Structural metadata, not arena metadata |

#### C. Traversal Orders

| Traversal | What it provides | Why not in Buffer/Arena |
|-----------|-----------------|------------------------|
| `forEachPreOrder(_:)` | Root-first depth-first walk | Requires parent-child structure |
| `forEachPostOrder(_:)` | Children-first depth-first walk | Requires parent-child structure |
| `forEachLevelOrder(_:)` | Breadth-first walk | Requires depth concept from hierarchy |
| `forEachInOrder(_:)` (n == 2) | Left-root-right walk | Requires binary tree structure |
| `preOrder` / `postOrder` / `levelOrder` / `inOrder` sequences | Lazy traversal as Swift.Sequence | Same, plus protocol conformance |
| Iterator types (Pre, Post, Level, In) | IteratorProtocol conformance per order | Implements tree-discipline traversal |

#### D. Insert/Remove with Structural Invariant Maintenance

| Operation | What it provides | Why not in Buffer/Arena |
|-----------|-----------------|------------------------|
| `insert(_:at: .root)` | Establish root, enforce single-root invariant | Arena.insert does not know about "root" |
| `insert(_:at: .child(of:slot:))` | Wire parent-child link, enforce slot emptiness | Arena.insert does not maintain parent-child |
| `insert(_:at: .appendChild(of:))` | Append to dynamic child list | Arena.insert does not maintain child lists |
| `remove(at:)` (leaf only) | Enforce leaf-only removal, unwire from parent | Arena.remove/free does not check tree structure |
| `removeSubtree(at:)` | Post-order recursive removal of entire subtree | Arena has no subtree concept |
| `clear()` | Remove all nodes, reset root | Delegates to arena.removeAll but also resets `_rootIndex` |

#### E. Tree Metrics

| Metric | What it provides | Why not in Buffer/Arena |
|--------|-----------------|------------------------|
| `height` | Longest root-to-leaf path length | Requires hierarchical depth traversal |
| `count` | Number of nodes | Delegates to arena, but semantically "tree size" |
| `isEmpty` | Whether tree has nodes | Delegates to arena |
| `arity` (static) | Maximum children per node | Compile-time tree parameter, not arena concern |

#### F. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Tree.N<Element, n>` -- compile-time bounded arity | The tree promises at most `n` children per node. The arena is unaware of arity. |
| `Tree.Binary<Element>` -- typealias for N<Element, 2> | Names the binary specialization |
| `Tree.Unbounded<Element>` -- dynamic arity | Each node can have any number of children |
| `Tree.N.Bounded` -- fixed node capacity | Tree-level promise: "at most N nodes, throw on overflow" |
| `Tree.N.Inline` -- zero-allocation guarantee | Tree-level promise: "this never heap-allocates for nodes" |
| `Tree.N.Small` -- inline with spill | Tree-level promise: "inline for small trees, heap for large" |
| Conditional `Copyable where Element: Copyable` | Value semantics commitment for the tree |
| `@unchecked Sendable where Element: Sendable` | Concurrency safety commitment |

#### G. Position-Based Safety (Token Validation)

| Feature | What it provides |
|---------|-----------------|
| `Tree.Position` (index + token) | Type-safe cursor with stale-position detection |
| `_validate(_:)` | O(1) safety checking before any node access |
| Token odd/even scheme | Occupied (odd) vs free (even) distinction |

This is a **shared concern**. The token mechanism lives in `Buffer.Arena` (which provides `isValid`, `token(at:)`), but the `Tree.Position` type and the validation calls that wrap every navigation/mutation operation are tree-discipline. The tree decides *when* to validate; the arena decides *how* to validate.

#### H. Error Types

| Error | Category | Assessment |
|-------|----------|------------|
| `.slotOccupied` / `.rootOccupied` | **TREE** | Only meaningful in hierarchical context |
| `.cannotRemoveNonLeaf` | **TREE** | Leaf/non-leaf is tree structure |
| `.invalidPosition` | **SHARED** | Position concept is tree-level; token validation is arena-level |
| `.overflow` | **TREE** | "Tree is full" -- user-facing capacity contract |
| `.invalidCapacity` | **TREE** | Initialization-time constraint |
| `.childIndexOutOfBounds` | **TREE** | Child list indexing is tree structure |
| `.invalidSlot` | **TREE** | Arity-bounded slot indexing is tree structure |
| `.empty` | **TREE** | Tree emptiness is a structural concept |
| `.elementStrideTooLarge` / `.elementAlignmentTooLarge` | **CONTESTED** | These are arena/inline storage concerns exposed through tree error types (see below) |

#### I. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `N`/`N.Bounded`/`N.Inline`/`N.Small`/`Unbounded` family |
| `ChildSlot` with named convenience (`.left`, `.right`, `.northwest`, etc.) | Domain-specific slot naming |
| `InsertPosition` enum (`.root`, `.child(of:slot:)`, `.appendChild(of:)`) | Declarative insertion API |
| `Tree.Binary<Element>` typealias | Convenience for the common binary case |
| `CustomStringConvertible` on errors and ChildSlot | Debug ergonomics |
| `peek(at:)` with borrowing closure (for ~Copyable) | Safe element access pattern |
| `peek(at:)` returning `Element?` (for Copyable) | Convenience access |
| CoW-aware insert overloads (`makeUnique()` + insert) | Value semantics for Copyable trees |

### What Buffer.Arena Owns (Tree Merely Delegates)

| Concern | Owned by Buffer.Arena |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys storage |
| Capacity tracking | `Header.capacity` / slot count |
| Occupied count tracking | `Header.occupied` |
| Growth policy (dynamic variant) | Automatic doubling |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via node init/deinit |
| Generation token management | Token buffer with odd/even scheme |
| Free-list recycling | LIFO free-list for slot reuse |
| Pointer access | `pointer(at:)` raw pointer to slot |
| Slot validity checking | `isValid(_:)` token comparison |
| Inline storage layout (Inline variant) | `@_rawLayout` based storage |
| Spill mechanism (Small variant) | Inline-to-heap transition |
| Bounded capacity enforcement (Bounded variant) | Refuses insert when full |

---

## Audit: Current tree-primitives

### Audit Methodology

For each file in `tree-primitives/Sources/`, classify every public API member as:
- **TREE**: Solely tree discipline (structural invariant, navigation, traversal, hierarchy semantics)
- **DELEGATE**: Pure delegation to arena (thin wrapper calling `_arena.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Tree Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `Tree` namespace enum | Architecture | `Tree.swift` |
| `Tree.Binary<Element>` typealias | Architecture | `Tree.Binary.swift` |
| `Tree.Position` (index + token cursor) | Structural | `Tree.Position.swift` |
| `Tree.Index<Element>` typealias | Structural | `Tree.Index.swift` |
| `Tree.N<Element, n>` struct | Architecture | `Tree.N.swift` |
| `Tree.N.Node` (element + childIndices + childCount + parentIndex) | Structural | `Tree.N.swift` |
| `Tree.N.ChildSlot` (bounded slot index) | Structural | `Tree.N.ChildSlot.swift` |
| `Tree.N.InsertPosition` enum (.root, .child) | Structural | `Tree.N.InsertPosition.swift` |
| Binary convenience: `.left`, `.right` on ChildSlot and InsertPosition | Ergonomics | `Tree.N.ChildSlot.swift`, `Tree.N.InsertPosition.swift` |
| Ternary convenience: `.left`, `.middle`, `.right` | Ergonomics | Same files |
| Quad convenience: `.northwest`, `.northeast`, `.southwest`, `.southeast` | Ergonomics | Same files |
| `root` property (returns Position of root) | Navigation | All main variant files |
| `parent(of:)` | Navigation | All main variant files |
| `child(of:slot:)` / `child(of:at:)` | Navigation | All main variant files |
| `left(of:)` / `right(of:)` (n == 2) | Navigation | All main variant files |
| `leftmostChild(of:)` / `rightmostChild(of:)` (N-ary) | Navigation | `Tree.N.swift` |
| `firstChild(of:)` / `lastChild(of:)` (Unbounded) | Navigation | `Tree.Unbounded.swift` |
| `isLeaf(_:)` | Structural query | All main variant files |
| `childCount(of:)` | Structural query | All main variant files |
| `insert(_:at:)` with structural invariant enforcement | Mutation | All main variant files |
| `remove(at:)` with leaf-only enforcement | Mutation | All main variant files |
| `removeSubtree(at:)` with post-order cleanup | Mutation | All main variant files |
| `peek(at:_:)` (borrowing closure, ~Copyable) | Element access | All main variant files |
| `peek(at:)` (returning Element?, Copyable) | Element access | All Copyable extensions |
| `height` / `height()` | Tree metric | All main variant files |
| `arity` (static, N-ary only) | Tree parameter | `Tree.N.swift` |
| `_validate(_:)` position validation wrappers | Safety | All main variant files |
| `forEachPreOrder(_:)` | Traversal | All main variant files |
| `forEachPostOrder(_:)` | Traversal | All main variant files |
| `forEachLevelOrder(_:)` | Traversal | All main variant files |
| `forEachInOrder(_:)` (n == 2) | Traversal | All main variant files |
| `preOrder` / `postOrder` / `levelOrder` / `inOrder` sequence properties | Traversal | `Tree.N.Traversal.swift`, `Tree.N.Bounded.swift` |
| `Order.Pre.Sequence` / `Order.Post.Sequence` / `Order.Level.Sequence` / `Order.In.Sequence` | Traversal | All `*.Sequence.swift` files |
| `Order.Pre.Iterator` / `Order.Post.Iterator` / `Order.Level.Iterator` / `Order.In.Iterator` | Traversal | All `*.Iterator.swift` files |
| Bounded.Order.* mirror of above for Bounded variant | Traversal | All `Bounded.Order.*` files |
| `Tree.N.Error` (.empty, .invalidPosition, .slotOccupied, .cannotRemoveNonLeaf, .invalidSlot, .invalidCapacity) | Error types | `Tree.N.Error.swift` |
| `Tree.N.Bounded.Error` (adds .overflow) | Error types | `Tree.N.Bounded.Error.swift` |
| `Tree.N.Inline.Error` | Error types | `Tree.N.Inline.Error.swift` |
| `Tree.N.Small.Error` | Error types | `Tree.N.Small.Error.swift` |
| `Tree.Unbounded.Error` (.rootOccupied, .childIndexOutOfBounds, .cannotRemoveNonLeaf) | Error types | `Tree.Unbounded.Error.swift` |
| `Tree.Unbounded.Bounded.Error` | Error types | `Tree.Unbounded.Bounded.Error.swift` |
| `Tree.Unbounded.Small.Error` | Error types | `Tree.Unbounded.Small.Error.swift` |
| `Tree.Unbounded<Element>` struct | Architecture | `Tree.Unbounded.swift` |
| `Tree.Unbounded.InsertPosition` (.root, .child(of:at:), .appendChild(of:)) | Structural | `Tree.Unbounded.InsertPosition.swift` |
| `Tree.N.Bounded` struct | Architecture | `Tree.N.Bounded.swift` |
| `Tree.N.Inline` struct | Architecture | `Tree.N.Inline.swift` |
| `Tree.N.Small` struct | Architecture | `Tree.N.Small.swift` |
| Conditional `Copyable where Element: Copyable` | Type invariant | Multiple files |
| `@unchecked Sendable where Element: Sendable` | Type invariant | Multiple files |
| `CustomStringConvertible` on errors and ChildSlot | Ergonomics | Error files, `Tree.N.ChildSlot.swift` |
| `clear()` (resets `_rootIndex` in addition to arena) | Mutation | All main variant files |
| `makeUnique()` (CoW-aware insert path) | Value semantics | `Tree.N.swift`, `Tree.N.Bounded.swift`, `Tree.Unbounded.swift` |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `_arena.occupied` | Buffer.Arena | **OK** -- Tree surface for arena state |
| `var isEmpty` -> `_arena.isEmpty` | Buffer.Arena | **OK** |
| `var isFull` -> `_arena.isFull` (Bounded/Inline) | Buffer.Arena | **OK** |
| `var capacity` (Bounded) | Buffer.Arena.Bounded | **OK** -- stored property, not delegation |
| `var isSpilled` -> `_arena.isSpilled` (Small) | Buffer.Arena.Small | **CONTESTED** (see below) |
| `makeUnique()` -> `_arena.ensureUnique()` | Buffer.Arena | **OK** -- Tree adds the *when*; arena provides the *how* |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `Tree.N.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** -- a user reasonably wants to know if their small tree has spilled to heap. This is a valid consumer-facing diagnostic property, identical to the rationale accepted for `Array.Small.isSpilled` in the array audit. Keep it. |
| `.elementStrideTooLarge` / `.elementAlignmentTooLarge` in `Tree.N.Inline.Error` and `Tree.N.Small.Error` | These errors describe inline storage layout constraints, which are arena/buffer concerns, not tree structural concerns. | **MINOR LEAK** -- These error cases expose arena-level implementation details (stride and alignment of inline slots) through the tree's error type. A user encountering `.elementStrideTooLarge` is dealing with an inline storage limitation, not a tree invariant violation. However, the tree *chose* the Inline variant as a type-level commitment, so surfacing its constraints is defensible. Consider whether these should be caught at compile time rather than runtime. |
| `Tree.Unbounded.Node.childIndices` uses `Swift.Array<Int>` | The WORKAROUND comment explains: Array_Primitives lacks stdlib-compatible mutation APIs needed for dynamic child lists (`firstIndex(of:)`, `insert(_:at:)`, `remove(at:)` with bare Int). | **ACKNOWLEDGED TECH DEBT** -- documented in the file with tracking reference (Phase 5 / F-04). The use of `Swift.Array` is an implementation detail of the node type, which is `@usableFromInline` (not public). No layering violation, but the dependency on Swift stdlib's Array is noted. |
| `exports.swift` re-exports 8 packages | `@_exported import Stack_Primitives`, `Queue_Primitives`, `Array_Primitives`, `Index_Primitives`, `Input_Primitives`, `Bit_Primitives`, `Collection_Primitives`, `Buffer_Arena_Primitives` | **OBSERVATION** -- The re-exports expose buffer/arena types to consumers of tree-primitives. This is a deliberate API surface choice (consumers can use arena directly). Whether this is too broad is a separate question from layering violations -- re-exports do not constitute *leaking* arena concerns into the tree API; they merely make the arena available alongside it. |
| Iterators directly access `tree._arena.pointer(at:)` | Iterator implementations reach into the tree's internal arena to traverse nodes. | **OK** -- The iterators are `public struct` types nested inside the tree's `Order` namespace. They implement tree-discipline traversal logic (pre/post/level/in-order) using the arena's storage API. The arena access is an implementation detail of the traversal, not a leaked concern. The iterator *types* are tree-discipline; the pointer access is the necessary bridge. |
| `_slot(_:)` / `_rawIndex(_:)` helper methods | Type-conversion between `Index<Node>` and raw `Int`. | **OK** -- These are `@usableFromInline` internal helpers, not public API. They exist at the boundary between tree-level typed indices and arena-level raw indices. This is the correct place for such conversions. |

### What's MISSING from Tree (things that are solely tree discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `Equatable where Element: Equatable` | Algebraic | Medium -- structural equality (same shape + same elements) is core tree semantics. Requires simultaneous traversal of two trees. |
| `Hashable where Element: Hashable` | Algebraic | Medium -- follows from Equatable |
| `depth(of:)` / `level(of:)` | Tree metric | Medium -- distance from root to a specific node. Currently only `height` (global max depth) is provided. |
| `contains(_:) where Element: Equatable` | Query | Low -- can be implemented via traversal, but a direct method is ergonomic |
| `map(_:)` returning a new tree | Functor | Medium -- structure-preserving transformation is a fundamental tree operation (Haskell Data.Tree is a Functor) |
| `reduce(_:_:)` / fold | Foldable | Low -- can be done with forEach, but explicit fold captures the algebraic pattern |
| `sibling(of:)` / `nextSibling(of:)` | Navigation | Low -- useful for n-ary tree traversal but not fundamental |
| Subtree extraction (`subtree(at:) -> Tree`) | Structural | Low -- extracting a subtree as a new tree is a tree operation |
| `CustomStringConvertible` / `CustomDebugStringConvertible` on tree types | Ergonomics | Low |
| `Codable where Element: Codable` | Serialization | Low for primitives |
| Traversal sequences for `Unbounded` variant | Traversal | Medium -- `Tree.N` and `Tree.N.Bounded` have `Order.*.Sequence` types, but `Tree.Unbounded` only has `forEach*` closures, no `Sequence`-conforming types |
| Traversal sequences for `Inline` and `Small` variants | Traversal | Low -- these are ~Copyable, making Sequence conformance complex |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: tree-primitives is well-layered

The current `tree-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Structural invariant** (parent-child hierarchy, root, leaf, arity) -- solely tree discipline
2. **Navigation** (parent, child, left, right, leftmost, rightmost) -- solely tree discipline
3. **Traversal** (pre-order, post-order, level-order, in-order) -- solely tree discipline
4. **Structural mutation** (insert with hierarchy wiring, remove with leaf enforcement, subtree removal) -- solely tree discipline
5. **Pure delegation** (count, isEmpty, isFull) -- thin wrappers exposing arena state through tree surface

The tree's relationship with its underlying `Buffer<Node>.Arena` is analogous to Array's relationship with `Buffer.Linear`: the tree wraps the arena, adds structural invariants (parent-child links, traversal orders, arity constraints), and presents a consumer-facing API that is entirely about the hierarchical data structure.

### Specific Recommendations

#### 1. Review `.elementStrideTooLarge` / `.elementAlignmentTooLarge` in error types (Minor)

`Tree.N.Inline.Error` and `Tree.N.Small.Error` include `.elementStrideTooLarge` and `.elementAlignmentTooLarge` cases that describe inline storage layout constraints. These are arena-level concerns surfaced through tree error types. While defensible (the user chose the Inline variant), consider whether these should be:
- Caught at compile time via static assertions (preferred), or
- Kept as-is with documentation noting these are storage-variant-specific

#### 2. Add traversal sequences for `Tree.Unbounded` (Medium Priority)

`Tree.N` and `Tree.N.Bounded` have full `Order.Pre.Sequence`, `Order.Post.Sequence`, etc. The `Unbounded` variant only has `forEachPreOrder`/`forEachPostOrder`/`forEachLevelOrder` closures. For parity and ergonomics, add `Sequence`-conforming traversal types for `Tree.Unbounded`.

#### 3. Add `Equatable` / `Hashable` (Medium Priority)

Structural equality (same shape and same elements in the same positions) is a core tree-discipline semantic. Currently absent from all variants.

#### 4. `isSpilled` is acceptable

`Tree.N.Small.isSpilled` exposes a buffer detail, but it is a diagnostic property that users legitimately need. The SmallVec/SmallTree pattern's value proposition depends on knowing when you have spilled. Keep it. This is consistent with the accepted verdict for `Array.Small.isSpilled`.

#### 5. No buffer/arena concerns have leaked upward

The audit found **zero instances** of tree-primitives doing work that properly belongs to the buffer/arena layer. All storage management, growth, CoW, element lifecycle, generation-token management, free-list recycling, and contiguous-memory operations are handled by `Buffer<Node>.Arena` and its variants. Tree's `_arena` stored property is the only coupling, and it is correctly `@usableFromInline`-scoped (not public).

#### 6. Swift.Array in Unbounded.Node is documented tech debt, not a layering violation

The use of `Swift.Array<Int>` for `childIndices` in `Tree.Unbounded.Node` is documented with a WORKAROUND comment and tracking reference (Phase 5 / F-04). The node type is `@usableFromInline` (not public), so this does not affect the public API surface. Resolve when Array_Primitives gains the required mutation APIs.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure tree discipline | 50+ distinct public APIs | Correctly placed |
| Pure delegation | 5-6 passthrough properties | Correctly placed -- thin wrapping is the design intent |
| Buffer/arena concern leaked into tree | **0** | Clean separation |
| Minor leaks (error cases) | 2 error cases | `.elementStrideTooLarge` / `.elementAlignmentTooLarge` are defensible |
| Tree concern missing | 8-11 items | Future work, not a layering violation |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms
- Haskell `Data.Tree`: Rose tree algebraic definition, Functor/Foldable/Traversable
- Haskell `tree-traversals` package: In-order, pre-order, post-order, level-order traversals for tree-like types
- Rust `btree-slab` crate: BTreeMap on slab storage, demonstrating tree/arena separation
- Rust `btree-plus-store` crate: Arena + slab allocation for B-trees
- Rust Collections Case Study: BTreeMap internals
- [Inside STL: map, set, multimap, multiset - Old New Thing](https://devblogs.microsoft.com/oldnewthing/20230807-00/?p=108562): Red-black tree internals
- [STL's Red-Black Trees - Dr Dobb's](https://www.drdobbs.com/cpp/stls-red-black-trees/184410531): Node allocation with free-list reuse
- [Why std::map is Red-Black Tree](https://gist.github.com/justinmeiners/57f38bddae9029db3c6401fae113bd7c): Stepanov's B*-tree observation
- [Abseil B-tree Containers](https://abseil.io/about/design/btree): Cache-friendly alternative to red-black trees
- [An Introduction to Separation Logic - Reynolds](https://www.cs.cmu.edu/~jcr/copenhagen08.pdf): Shape vs data vs memory separation
- [Modular Verification of Intrusive List and Tree](https://drops.dagstuhl.de/storage/00lipics/lipics-vol309-itp2024/LIPIcs.ITP.2024.19/LIPIcs.ITP.2024.19.pdf): Tree view predicates separating node structure from data
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`: Companion array audit
