# swift-tree-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (automated)
**Skills**: /implementation [IMPL-*], /naming [API-NAME-*]
**Scope**: All .swift files in `Sources/` (80 files, 7 modules)
**Mode**: READ-ONLY

## Summary Table

| ID | Severity | Rule | File | Description |
|-----|----------|------|------|-------------|
| TREE-001 | HIGH | [API-NAME-002] | Tree.N.swift:259,157,167,172 | `childCount(of:)` compound method (x5 variants) |
| TREE-002 | HIGH | [API-NAME-002] | Tree.N.swift:273 | `leftmostChild(of:)` compound method |
| TREE-003 | HIGH | [API-NAME-002] | Tree.N.swift:294 | `rightmostChild(of:)` compound method |
| TREE-004 | HIGH | [API-NAME-002] | Tree.N.swift:431,268,276,281 | `removeSubtree(at:)` compound method (x5 variants) |
| TREE-005 | HIGH | [API-NAME-002] | Tree.N.swift:565 | `forEachPreOrder(_:)` compound method (x5 variants) |
| TREE-006 | HIGH | [API-NAME-002] | Tree.N.swift:589 | `forEachPostOrder(_:)` compound method (x5 variants) |
| TREE-007 | HIGH | [API-NAME-002] | Tree.N.swift:645 | `forEachLevelOrder(_:)` compound method (x5 variants) |
| TREE-008 | HIGH | [API-NAME-002] | Tree.N.swift:678 | `forEachInOrder(_:)` compound method (x5 variants) |
| TREE-009 | HIGH | [API-NAME-002] | Tree.Keyed.Navigation.swift:131 | `forEachChild(of:_:)` compound method |
| TREE-010 | HIGH | [API-NAME-002] | Tree.Unbounded.swift:277 | `firstChild(of:)` compound method |
| TREE-011 | HIGH | [API-NAME-002] | Tree.Unbounded.swift:286 | `lastChild(of:)` compound method |
| TREE-012 | HIGH | [API-NAME-002] | Tree.Keyed.swift:451 | `rootValue` compound property |
| TREE-013 | HIGH | [API-NAME-002] | Tree.Keyed.MapValues.swift:21 | `mapValues(_:)` compound method (x4 variants + async) |
| TREE-014 | HIGH | [API-NAME-002] | Tree.Keyed.MapValues.swift:110,133,206 | `compactMapValues(_:)` compound method (x4 variants + async) |
| TREE-015 | HIGH | [API-NAME-002] | Tree.N.Traversal.swift:17,27 | `preOrder`/`postOrder`/`levelOrder`/`inOrder` compound properties |
| TREE-016 | MEDIUM | [IMPL-010] | Tree.N.swift:189 | `Int(bitPattern:)` at non-boundary `_validate` |
| TREE-017 | MEDIUM | [IMPL-010] | Tree.N.Bounded.swift:104 | `Int(bitPattern:)` at non-boundary `_validate` |
| TREE-018 | MEDIUM | [IMPL-010] | Tree.Keyed.swift:183 | `Int(bitPattern:)` at non-boundary `_validate` |
| TREE-019 | MEDIUM | [IMPL-010] | Tree.Unbounded.swift:192 | `Int(bitPattern:)` at non-boundary `_validate` |
| TREE-020 | MEDIUM | [IMPL-010] | Tree.Unbounded.swift:141 | `_rawIndex` helper exposes `Int(bitPattern:)` |
| TREE-021 | MEDIUM | [IMPL-010] | Tree.Unbounded.swift:377 | `Int(bitPattern: position.index)` at call site in `remove(at:)` |
| TREE-022 | MEDIUM | [IMPL-010] | Tree.Unbounded.swift:405 | `Int(bitPattern: position.index)` at call site in `removeSubtree(at:)` |
| TREE-023 | MEDIUM | [IMPL-010] | Tree.Unbounded.swift:417 | `Int(bitPattern: position.index)` at call site in `removeSubtree(at:)` |
| TREE-024 | LOW | [IMPL-INTENT] | Tree.N.swift:107 | `childCount` stored property on Node is a bare name, fine for struct field |
| TREE-025 | MEDIUM | [API-IMPL-005] | Tree.N.swift | Node struct defined inside Tree.N (same file), not in separate file |
| TREE-026 | INFO | [API-NAME-001] | Tree.Position.swift | `__TreePosition` hoisted type -- documented exception [API-EXC-001] |
| TREE-027 | INFO | [API-NAME-001] | Tree.N.ChildSlot.swift | `__TreeNChildSlot` hoisted type -- documented exception [API-EXC-001] |
| TREE-028 | INFO | [API-NAME-001] | Tree.N.InsertPosition.swift | `__TreeNInsertPosition` hoisted type -- documented exception [API-EXC-001] |
| TREE-029 | INFO | [API-NAME-001] | Tree.N.Error.swift | `__TreeNError` hoisted type -- documented exception [API-EXC-001] |
| TREE-030 | LOW | [IMPL-033] | Tree.N.swift:280,301 | `for slot in 0..<n` / `stride(from:through:by:)` bare Int iteration |
| TREE-031 | LOW | [IMPL-INTENT] | Tree.Unbounded.swift:103 | `childIndices: Swift.Array<Int>` -- bare Int children (documented workaround F-04) |
| TREE-032 | MEDIUM | [PATTERN-017] | Tree.Unbounded.swift:338,350 | `_rawIndex(arenaPos.slot)` leaks raw index into parent's childIndices |
| TREE-033 | LOW | [IMPL-INTENT] | Tree.N.Inline.swift:113 | `Int(bitPattern: position.index) < capacity` -- bounds check on raw Int |
| TREE-034 | LOW | [IMPL-INTENT] | Tree.N.Small.swift:136 | `position.token & 1 == 1` -- manual bit check rather than named predicate |
| TREE-035 | LOW | [IMPL-INTENT] | Tree.N.Inline.swift:116 | `position.token & 1 == 1` -- manual bit check rather than named predicate |
| TREE-036 | LOW | [IMPL-030] | Tree.Keyed.Subscript.swift:62,108 | `try?` discards error for convenience subscript insert/update |

## Findings Detail

---

### [TREE-001] `childCount(of:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:259, Tree.N.Bounded.swift:157, Tree.N.Inline.swift:167, Tree.N.Small.swift:172, Tree.Keyed.Navigation.swift:89, Tree.Unbounded.swift:263

The method `childCount(of:)` is a compound identifier. Per [API-NAME-002], methods MUST NOT use compound names.

**Suggested fix**: Use nested accessor pattern, e.g. `children.count(of:)` or expose via a `.children` accessor that provides `.count`.

**Current**:
```swift
public func childCount(of position: Tree.Position) -> Count?
```

**Expected pattern**:
```swift
// Via nested accessor:
tree.children(of: position).count
```

---

### [TREE-002] `leftmostChild(of:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.N.swift:273

**Current**: `public func leftmostChild(of position: Tree.Position) -> Tree.Position?`

**Expected pattern**: `tree.child.leftmost(of: position)` or `tree.children(of: position).first`

---

### [TREE-003] `rightmostChild(of:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.N.swift:294

**Current**: `public func rightmostChild(of position: Tree.Position) -> Tree.Position?`

**Expected pattern**: `tree.child.rightmost(of: position)` or `tree.children(of: position).last`

---

### [TREE-004] `removeSubtree(at:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:431, Tree.N.Bounded.swift:268, Tree.N.Inline.swift:276, Tree.N.Small.swift:281, Tree.Keyed.swift:273

**Current**: `public mutating func removeSubtree(at position: Tree.Position)`

**Expected pattern**: `tree.remove.subtree(at: position)` or `tree.subtree.remove(at: position)`

The pattern occurs in 5 variants (N, Bounded, Inline, Small, Keyed).

---

### [TREE-005] `forEachPreOrder(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:565, Tree.N.Bounded.swift:379, Tree.N.Inline.swift:386, Tree.N.Small.swift:368, Tree.Keyed.Traversal.swift:23

**Current**: `public func forEachPreOrder(_ body: (borrowing Element) -> Void)`

**Expected pattern**: The sequence-based API already exists (`preOrder` property). The `forEachPreOrder` method should ideally be `forEach.preOrder` or replaced entirely by the `preOrder` sequence for Copyable elements. For ~Copyable, the closure-based API is necessary but should use the nested accessor pattern.

---

### [TREE-006] `forEachPostOrder(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:589, Tree.N.Bounded.swift:399, Tree.N.Inline.swift:405, Tree.N.Small.swift:390, Tree.Keyed.Traversal.swift:51

Same pattern as TREE-005 for post-order.

---

### [TREE-007] `forEachLevelOrder(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:645, Tree.N.Bounded.swift:446, Tree.N.Inline.swift:451, Tree.N.Small.swift:437, Tree.Keyed.Traversal.swift:85

Same pattern as TREE-005 for level-order.

---

### [TREE-008] `forEachInOrder(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.swift:678, Tree.N.Bounded.swift:473, Tree.N.Inline.swift:477, Tree.N.Small.swift:494

Same pattern as TREE-005 for in-order (binary trees only).

---

### [TREE-009] `forEachChild(of:_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.Keyed.Navigation.swift:131

**Current**: `public func forEachChild(of position: Tree.Position, _ body: (Key, Tree.Position) -> Void)`

**Expected pattern**: `tree.children(of: position).forEach { ... }` -- the `children(of:)` method already exists and returns `[(key: Key, position: Tree.Position)]?`.

---

### [TREE-010] `firstChild(of:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.Unbounded.swift:277

**Current**: `public func firstChild(of position: Tree.Position) -> Tree.Position?`

**Expected pattern**: `tree.child.first(of: position)` or `tree.children(of: position).first`

---

### [TREE-011] `lastChild(of:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.Unbounded.swift:286

**Current**: `public func lastChild(of position: Tree.Position) -> Tree.Position?`

**Expected pattern**: `tree.child.last(of: position)` or `tree.children(of: position).last`

---

### [TREE-012] `rootValue` -- compound property name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Location**: Tree.Keyed.swift:379 (get/set)

**Current**: `public var rootValue: Value?`

**Expected pattern**: `tree.root.value` (via a root accessor that provides `.value`), or since `root` already returns `Tree.Position?`, callers should use `tree.peek(at: tree.root!)`.

---

### [TREE-013] `mapValues(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.Keyed.MapValues.swift:21, 67, 89, 252, 262

**Current**: `public func mapValues<U>(_ transform: (Value) -> U) -> Tree<U>.Keyed<Key>`

**Expected pattern**: `tree.values.map { ... }` -- separate `.values` accessor providing a map operation. The stdlib uses `mapValues` on Dictionary, but the institute style mandates decomposition.

---

### [TREE-014] `compactMapValues(_:)` -- compound method name
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.Keyed.MapValues.swift:110, 133, 206, 272, 282

Same decomposition issue as TREE-013. Should be `tree.values.compactMap { ... }`.

---

### [TREE-015] `preOrder`/`postOrder`/`levelOrder`/`inOrder` -- compound properties
**Rule**: [API-NAME-002]
**Severity**: HIGH
**Locations**: Tree.N.Traversal.swift:17,22,27; Tree.N.Traversal.swift:39 (inOrder)

**Current**:
```swift
public var preOrder: Order.Pre.Sequence { ... }
public var postOrder: Order.Post.Sequence { ... }
public var levelOrder: Order.Level.Sequence { ... }
public var inOrder: Order.In.Sequence { ... }
```

**Expected pattern**: These are compound properties. The nested namespace `Order.Pre` already exists. The access pattern should be:
```swift
tree.order.pre   // -> Order.Pre.Sequence
tree.order.post  // -> Order.Post.Sequence
tree.order.level // -> Order.Level.Sequence
tree.order.in    // -> Order.In.Sequence
```

This requires an `order` accessor property returning a view type.

---

### [TREE-016..019] `Int(bitPattern:)` in `_validate` methods
**Rule**: [IMPL-010]
**Severity**: MEDIUM
**Locations**:
- Tree.N.swift:189
- Tree.N.Bounded.swift:104
- Tree.Keyed.swift:183
- Tree.Unbounded.swift:192

All four `_validate` methods contain:
```swift
let arenaPos = Buffer<Node>.Arena.Position(
    index: UInt32(Int(bitPattern: position.index)), token: position.token
)
```

Per [IMPL-010], `Int(bitPattern:)` should be confined to boundary overloads, not repeated in each variant. The `Buffer.Arena.Position` init should accept `Index<__TreePosition>` directly, or a shared boundary overload should exist in Tree.Position that converts to arena position.

---

### [TREE-020] `_rawIndex` helper leaks `Int(bitPattern:)`
**Rule**: [IMPL-010] / [PATTERN-017]
**Severity**: MEDIUM
**Location**: Tree.Unbounded.swift:141

```swift
func _rawIndex(_ index: Index<Node>) -> Int {
    Int(bitPattern: index)
}
```

This is an internal boundary helper, which is acceptable per [IMPL-010]. However, it is then used at multiple call sites (lines 338, 350, 487, 515, 539, etc.) which spread the raw Int domain throughout the implementation. The underlying issue is that `Unbounded.Node.childIndices` is `Swift.Array<Int>` rather than typed indices (documented workaround F-04).

---

### [TREE-021..023] `Int(bitPattern: position.index)` at call sites
**Rule**: [IMPL-010]
**Severity**: MEDIUM
**Locations**: Tree.Unbounded.swift:377, 405, 417

Direct `Int(bitPattern: position.index)` appears at call sites in `remove(at:)` and `removeSubtree(at:)`, not confined to boundary code. These should route through the existing `_rawIndex` boundary helper or through `_slot` + a typed-to-raw boundary.

---

### [TREE-025] Node struct in same file as Tree.N
**Rule**: [API-IMPL-005]
**Severity**: MEDIUM
**Location**: Tree.N.swift:101

`Tree.N.Node` is defined inside Tree.N.swift at line 101. Per [API-IMPL-005], each type should be in its own file: `Tree.N.Node.swift`. The same applies to `Tree.Unbounded.Node` (Tree.Unbounded.swift:90) and `Tree.Keyed.Node` (Tree.Keyed.swift:84).

Note: These are nested structs inside value-generic types, and the Swift limitation on nested types in generic extensions may justify keeping them in the parent file. However, the rule makes no exception for nested types -- only [PATTERN-022] covers `~Copyable nested types in separate files`.

---

### [TREE-026..029] Hoisted `__Tree*` types -- documented exceptions
**Rule**: [API-NAME-001]
**Severity**: INFO (no action needed)
**Locations**: Tree.Position.swift, Tree.N.ChildSlot.swift, Tree.N.InsertPosition.swift, Tree.N.Error.swift, and all variant Error types

All hoisted types (`__TreePosition`, `__TreeNChildSlot`, `__TreeNInsertPosition`, `__TreeNError`, `__TreeNBoundedError`, `__TreeNInlineError`, `__TreeNSmallError`, `__TreeUnboundedError`, `__TreeUnboundedBoundedError`, `__TreeUnboundedSmallError`, `__TreeKeyedError`, `__TreeKeyedInsertPosition`, `__TreeUnboundedInsertPosition`, `__TreeKeyedDiff`) are documented exceptions under [API-EXC-001] with typealiases providing the Nest.Name form. No violation.

---

### [TREE-030] Bare Int iteration for slot traversal
**Rule**: [IMPL-033]
**Severity**: LOW
**Locations**: Many (Tree.N.swift:280, 301, 406, 464, etc.)

```swift
for slot in 0..<n { ... }
for slot in stride(from: n - 1, through: 0, by: -1) { ... }
```

The `slot` variable is an untyped `Int` iterating over child slot indices. Per [IMPL-033], iteration should express intent. A `ChildSlot.all` or `ChildSlot.allReversed` sequence would be more intent-expressive. However, given that `n` is a value-generic `Int` and `ChildSlot` is a bounded wrapper, this is partially justified by the low-level nature of arena traversal.

---

### [TREE-031] `childIndices: Swift.Array<Int>` in Unbounded.Node
**Rule**: [IMPL-INTENT]
**Severity**: LOW
**Location**: Tree.Unbounded.swift:103

The Unbounded variant stores children as `Swift.Array<Int>` rather than typed indices. This is a documented workaround (Phase 5 / F-04) pending Array_Primitives API parity. The entire Unbounded implementation operates in bare-Int domain as a consequence.

---

### [TREE-032] `_rawIndex` leaks raw domain into parent's childIndices
**Rule**: [PATTERN-017]
**Severity**: MEDIUM
**Locations**: Tree.Unbounded.swift:338, 350

```swift
let index = _rawIndex(arenaPos.slot)
unsafe (parentPtr.pointee.childIndices.insert(index, at: childIndex))
```

Raw Int values flow into the parent's `childIndices` array. This is a consequence of TREE-031 (documented workaround). Resolution depends on completing F-04.

---

### [TREE-033..035] Manual bit checks instead of named predicates
**Rule**: [IMPL-INTENT]
**Severity**: LOW
**Locations**: Tree.N.Inline.swift:113, 116; Tree.N.Small.swift:136

```swift
guard Int(bitPattern: position.index) < capacity else { throw .invalidPosition }
guard token == position.token, position.token & 1 == 1 else { throw .invalidPosition }
```

The `& 1 == 1` bit check (odd = occupied) reads as mechanism, not intent. A named predicate like `isOccupiedToken(position.token)` would improve readability. The N and Bounded variants delegate to `_arena.isValid()` which encapsulates this, but Inline and Small do manual checks.

---

### [TREE-036] `try?` discards typed error in subscript
**Rule**: [IMPL-030]
**Severity**: LOW
**Location**: Tree.Keyed.Subscript.swift:62, 108

```swift
_ = try? update(newValue, at: keyPath)
_ = try? insert(newValue, at: .root)
```

The sparse subscript setter uses `try?` to discard typed errors. This is arguably intentional for subscript convenience (subscripts cannot throw), but it silently swallows `__TreeKeyedError`.

---

## Statistics

| Category | Count |
|----------|-------|
| [API-NAME-002] compound method/property violations | 15 finding groups (affecting ~50+ method declarations across 5 variants) |
| [IMPL-010] Int(bitPattern:) outside boundary code | 8 locations |
| [PATTERN-017] rawValue leaking to call sites | 2 locations |
| [API-IMPL-005] multiple types per file | 3 files |
| [IMPL-INTENT] mechanism over intent | 3 locations |
| [IMPL-033] bare-Int iteration | many locations (systemic) |
| Documented exceptions [API-EXC-001] | 14 hoisted types (compliant) |

## Assessment

The package has **good structural compliance**: namespace hierarchy (Tree.N, Tree.N.Bounded, Tree.Keyed, etc.), one-file-per-type for most types, typed indices (Index<Node>), typed throws throughout, and proper use of `.retag()` for index domain crossing. The hoisted types are properly documented as exceptions.

The dominant issue is **compound method names** ([API-NAME-002]). The 15 finding groups represent a systemic pattern where tree operations use CompoundVerb naming (`removeSubtree`, `childCount`, `forEachPreOrder`, `mapValues`, `leftmostChild`, `firstChild`, etc.) instead of the nested accessor pattern (`remove.subtree`, `children.count`, `order.pre.forEach`, `values.map`, `child.first`). This affects approximately 50+ public method declarations across the five N-ary variants plus Keyed and Unbounded.

The secondary issue is **Int(bitPattern:) at non-boundary locations** ([IMPL-010]), with 8 occurrences across 4 `_validate` methods and 4 direct call sites in Unbounded. The Unbounded variant has a broader raw-Int domain issue tied to the documented F-04 workaround.

**No [API-NAME-001] violations** were found. All types use the Nest.Name pattern correctly.
**No Foundation imports** were found.
**Typed throws** are used throughout (all error types are typed).
**`.retag()` is used** instead of `__unchecked` for index domain crossing (Tree.N.swift:135, etc.) -- the `__unchecked` in ChildSlot (line 54) is an internal init for static factory methods, not a call-site usage.
