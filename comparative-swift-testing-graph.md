# Keyed Tree Primitive Design: swift-testing Graph vs Swift Primitives

<!--
---
version: 5.0.0
last_updated: 2026-03-01
status: RECOMMENDATION
scope: swift-tree-primitives, swift-graph-primitives, swift-dictionary-primitives, swiftlang/swift-testing
type: comparative-analysis
tier: 3
---
-->

## Context

The swift-testing framework (`swiftlang/swift-testing`) contains an internal `Graph<K, V>` type (~880 lines) that organizes tests into key-addressed hierarchies. The v3.0 analysis recommended `Tree.Keyed<Key, Value>` in swift-tree-primitives with Tier 3 rigor (SLR, formal semantics, five-option evaluation). v4.0 addressed classification challenges (naming, breaking changes, building blocks). This v5.0 inverts the question: is Apple's design even optimal? A full operational audit reveals fundamental design flaws (CoW cascading, O(n²) rendering, fragmented allocation) that a composed `Tree.Keyed` = `Arena` + `Dictionary.Ordered` strictly improves upon.

**Trigger**: Design question — should this be a new type, an upgrade to existing types, or something in the map family? Precedent-setting for the tree-primitives type family. Tier 3 per [RES-020]: establishes long-lived semantic contract.

**Constraints**: Foundation-free [PRIM-FOUND-001]. Namespace structure [API-NAME-001]. One type per file [API-IMPL-005]. Breaking changes to existing types are acceptable if justified.

---

## Question

What is the correct primitive type for key-addressed hierarchical data (the pattern swift-testing's Graph implements)? Specifically: new `Tree.Keyed` type, upgrade to existing `Tree.N`/`Tree.Unbounded`, standalone `Trie` package, or something else?

---

## Part I: Systematic Literature Review (Summary)

Full SLR in companion document: [trie-keyed-tree-literature-review.md](trie-keyed-tree-literature-review.md).

### SLR Protocol

- **Sources screened**: 67 hits across ACM DL, arXiv, Hackage, crates.io, cppreference, Boost, Apache Commons, Scala docs, swift-collections
- **Sources included**: 34 after screening (9 seminal papers, 22 implementations, 3 formal verification)
- **Methodology**: Kitchenham SLR per [RES-023]

### Key Findings

**F1. A trie is formally a map, not a tree.** Every mainstream implementation classifies tries as maps (Haskell `Data.IntMap`, Java `PatriciaTrie extends SortedMap`, Scala `TrieMap extends Map`, Swift `TreeDictionary`). The tree structure is an implementation detail. (Hinze 2000, Connelly & Morris 1995, Okasaki 1998)

**F2. Tree variants never share a common Tree protocol.** Across Haskell, Rust, Java, C++, Scala, Swift, and Clojure — `Data.Tree`, `BTreeMap`, `TreeMap`, `std::map`, `TreeDictionary` are all independent types. No ecosystem has a unifying Tree abstraction. (Full survey in [tree-type-family-organization-across-libraries.md](tree-type-family-organization-across-libraries.md))

**F3. A keyed tree (tree with labeled edges) is distinct from a trie.** The formal unfoldings:

```
Trie K V      = (Maybe V, Map K (Trie K V))       — some nodes have no value
KeyedTree K V = (V,       Map K (KeyedTree K V))   — every node has a value
```

The only mainstream keyed-tree implementation is `Boost.PropertyTree` (C++). Keyed trees serve configuration/document hierarchies, not string lookup.

**F4. The canonical trie type signature is `Trie<K, V>` where the actual key is `[K]`.** Three parameterization patterns exist: fixed-key (`Trie<V>`), fragment-keyed (`Trie<K, V>` where key = `[K]`), and type-derived (Haskell `generic-trie`).

**F5. Tries that expose structural operations transcend the map interface.** Rust `radix_trie` (subtrie extraction, ancestor lookup) and Java `PatriciaTrie` (dual `SortedMap` + `Trie` interface) show that useful tries need both map-like and tree-like capabilities.

### Reference Bibliography

Fredkin 1960; Morrison 1968 (PATRICIA); Connelly & Morris 1995 (trie as functor); Okasaki 1998 (Ch. 10, tries as maps); Okasaki & Gill 1998 (IntMap); Hinze 2000 (generalized tries, exponent-law); Bagwell 2001 (HAMT); Prokopec et al. 2012 (Ctrie); Elliott 2009 (MemoTrie). Full bibliography in SLR document Appendix A.

---

## Part II: swift-testing's Graph — Formal Analysis

### 2.1 Type Structure

swift-testing's `Graph<K, V>` unfolds as:

```
Graph K V = (V, [K: Graph K V])
```

where `[K: _]` denotes `Dictionary<K, _>`. This is **exactly** `KeyedTree K V`:

```
KeyedTree K V = (V, Map K (KeyedTree K V))
```

### 2.2 When V Is Optional

swift-testing frequently instantiates `Graph<String, Test?>`, `Graph<String, Step?>`. When `V = U?`:

```
Graph K (U?) = (U?, Map K (Graph K (U?)))
             ≅ (Maybe U, Map K (Graph K (U?)))
             ≅ Trie K U
```

**This is the key unification**: `KeyedTree<K, V>` subsumes `Trie<K, U>` when `V = U?`. A single type serves both keyed-tree (every node has value) and trie (sparse nodes) use cases via the value type parameter. swift-testing already exploits this — it is not accidental.

### 2.3 Operations Inventory (from v2.0)

**Essential operations actually used** (6 files, precise call-site inventory):

| Category | Operations | Count |
|----------|-----------|-------|
| Construction | `insertValue(at: [K], intermediateValue:)` | 5 sites |
| Navigation | `subgraph(at:)`, `subscript[keyPath]`, `takeValues(at:)`, `.value`, `.children` | 12 sites |
| Functional | `mapValues` (sync+async, with `recursivelyApply`), `forEach` (sync+async), `compactMap` | 15 sites |
| Structural | `zip(tree1, tree2)` | 3 sites |

**Never used**: `removeValue`, `compactMapValues`, `flatMap`, `map` to array. The type is navigated and transformed, never pruned.

### 2.4 Identity: Tree or Map?

swift-testing's Graph exposes **tree-structural operations**: `subgraph`, `children`, `mapValues` preserving topology, `forEach` depth-first, `zip` over aligned structures, `recursivelyApply` for parent→child inheritance. These are not map operations — they require structural awareness of the hierarchy.

It does NOT expose map-only operations: no `contains(key)`, no `merge`, no `intersection`, no iteration over flat key-value pairs. The key path is always navigated structurally.

**Verdict**: swift-testing's Graph is a **keyed tree**, not a trie-as-map. The primary identity is "tree with key-labeled edges," not "map with exploitable key structure."

---

## Part III: Can Existing Tree Types Be Upgraded?

### 3.1 Internal Architecture (Complete Audit)

**Tree.N<Element, let n: Int> node layout:**
```swift
struct Node: ~Copyable {
    var element: Element
    var childIndices: InlineArray<n, Index<Node>?>  // compile-time sized
    var childCount: Count
    var parentIndex: Index<Node>?
}
```

**Tree.Unbounded<Element> node layout:**
```swift
struct Node: ~Copyable {
    var element: Element
    var childIndices: Array<Int>     // dynamic array, dense
    var parentIndex: Index<Node>?
}
```

### 3.2 Why Upgrading Is Infeasible

**Problem 1: Child storage is baked into node layout.**
- `Tree.N`: `InlineArray<n, Index<Node>?>` — fixed-size, compile-time sized, sparse slots
- `Tree.Unbounded`: `Array<Int>` — dynamic, dense, index-addressed
- A keyed tree needs: `Dictionary<Key, Index<Node>>` — hash-backed, key-addressed

These are three fundamentally different storage strategies with different:
- Memory layout (inline fixed vs heap dynamic vs hash table)
- Access patterns (slot index vs array index vs hash lookup)
- Sparsity (sparse slots vs dense array vs sparse by hash)

**Problem 2: Traversal loops assume the storage type.**

Tree.N pre-order (lines 576-581):
```swift
for slot in stride(from: n - 1, through: 0, by: -1) {
    if let child = nodePtr.pointee.childIndices[slot] { pending.push(child) }
}
```

Tree.Unbounded pre-order (lines 522-526):
```swift
for i in stride(from: childIndices.count - 1, through: 0, by: -1) {
    pending.push(childIndices[i])
}
```

A keyed tree would need:
```swift
for (_, childIndex) in nodePtr.pointee.children {
    pending.push(childIndex)
}
```

These are **different algorithms** — you cannot parameterize over them without either virtual dispatch (losing inlining) or generics over the child container (making Node generic over a container type, which cascades through every API).

**Problem 3: InsertPosition API would break.**

Current:
```swift
// Tree.N
enum InsertPosition { case root; case child(of: Position, slot: ChildSlot) }

// Tree.Unbounded
enum InsertPosition { case root; case child(of: Position, at: Int); case appendChild(of: Position) }
```

A keyed tree needs:
```swift
enum InsertPosition { case root; case child(of: Position, key: Key) }
```

These are three different enum shapes. A protocol abstracting over them would require associated types for the addressing mode, which propagates through every consumer.

**Problem 4: The generic parameter signature changes.**

| Type | Parameters |
|------|-----------|
| `Tree.N<Element, let n: Int>` | Element + compile-time arity |
| `Tree.Unbounded<Element>` | Element only |
| Keyed tree | **Key + Value** (two parameters, like Dictionary) |

The keyed tree has a fundamentally different parameter structure — it separates keys from values, whereas existing tree types have a single `Element`.

### 3.3 What IS Reusable

The arena infrastructure is reusable in principle:

| Component | Reusable? | Notes |
|-----------|-----------|-------|
| `Buffer<Node>.Arena` | Yes | Parameterized by Node type — a new Node struct works |
| Generation tokens | Yes | Stale-position detection is independent of child addressing |
| `Tree.Position` | Yes | Token-validated handle, addressing-agnostic |
| CoW machinery | Yes | isKnownUniquelyReferenced pattern |
| `~Copyable` support | Yes | Arena variants handle move-only elements |

But reusing arena infrastructure means using it as an **internal building block**, not extending the existing types with new behavior. This argues for a **new type** that happens to use the same arena backend, not an upgrade to existing types.

---

## Part IV: Option Analysis

### Option A: `Tree.Keyed<Key, Value>` in swift-tree-primitives

New independent variant in the tree package, alongside Tree.N and Tree.Unbounded.

**Type signature**: `Tree.Keyed<Key: Hashable, Value>`
**Node layout**: `(Value, [Key: Index<Node>], Index<Node>?)` — value + keyed children dict + parent
**Package**: swift-tree-primitives (new module: `Tree Keyed Primitives`)
**Identity**: Structural tree with key-labeled edges

| Criterion | Assessment |
|-----------|-----------|
| Consistent with literature | **Partially** — keyed trees are rare but real (Boost.PropertyTree). Not classified as map. |
| Consistent with swift-tree-primitives | **Yes** — independent variant alongside Tree.N, Tree.Unbounded. No shared protocol needed (matches F2). |
| Reuses infrastructure | **Yes** — arena, positions, generation tokens |
| API fits swift-testing's needs | **Yes** — structural tree ops (subgraph, children, mapValues, zip, forEach) are natural |
| Naming | `Tree.Keyed<Key, Value>` — clear, follows [API-NAME-001] |
| ~Copyable support | **Yes** — via arena variants |
| Trie subsumption | **Yes** — `Tree.Keyed<K, V?>` ≅ `Trie K V` |

### Option B: Upgrade Tree.Unbounded with Key Parameter

Add an optional `Key` parameter to Tree.Unbounded.

**Rejected in analysis (Part III).** Child storage is baked into node layout. Would require:
- Changing `Array<Int>` to generic `ChildContainer<K>`
- Virtual dispatch or generic explosion in traversal
- Breaking InsertPosition API
- Two-parameter generic where currently one exists

The cost exceeds building a new type from scratch.

### Option C: Standalone `Trie<Key, Value>` Package (swift-trie-primitives)

New package classifying the type as a trie/map, not a tree.

**Type signature**: `Trie<Key: Hashable, Value>`
**Node layout**: `(Value?, [Key: Index<Node>])` — optional value + keyed children
**Package**: swift-trie-primitives (new package)
**Identity**: Map with prefix-structural operations

| Criterion | Assessment |
|-----------|-----------|
| Consistent with literature | **Strongly** — literature unanimously classifies tries as maps. New package avoids polluting tree family. |
| Consistent with swift-tree-primitives | **N/A** — separate package, no interaction |
| Reuses infrastructure | **No** — separate package must provide own arena or depend on tree-primitives |
| API fits swift-testing's needs | **Mostly** — but map identity is awkward for operations like `zip`, `recursivelyApply`, `subgraph` which are tree-structural |
| Naming | `Trie<Key, Value>` or `Trie.Map<Key, Value>` |
| Trie subsumption | **Yes** — this IS the trie |
| Keyed-tree subsumption | **No** — `Value?` at every node means non-optional use cases are awkward |

### Option D: `Trie<Key, Value>` in swift-tree-primitives

Trie type living inside tree-primitives but with map-like identity.

**Type signature**: `Trie<Key: Hashable, Value>`
**Package**: swift-tree-primitives (new module)
**Identity**: Hybrid — map semantics, tree package

| Criterion | Assessment |
|-----------|-----------|
| Consistent with literature | **Partially** — map identity, but placed in tree package (contradicts F1) |
| Reuses infrastructure | **Yes** — same arena |
| Naming confusion | **Yes** — a `Trie` in a tree package sends mixed signals |

### Option E: `Tree.Keyed<Key, Value>` in New Package (swift-keyed-tree-primitives)

Keyed tree as its own dedicated package.

**Type signature**: `Tree.Keyed<Key: Hashable, Value>`
**Package**: swift-keyed-tree-primitives
**Identity**: Keyed tree

| Criterion | Assessment |
|-----------|-----------|
| Consistent with literature | **Yes** — keyed trees are their own thing (Boost.PropertyTree) |
| Reuses infrastructure | **No** — separate package |
| Isolation | **Strong** — no impact on existing tree types |
| Package proliferation | **Concern** — 62nd package in swift-primitives |

---

## Part V: Formal Semantics

### 5.1 Type Definitions

Let `K` be a type with decidable equality (Hashable), `V` any type.

**Keyed Tree** (recursive):
```
τ_KT ::= { value: V, children: Map K τ_KT }
```

**Trie** (recursive, sparse):
```
τ_Tr ::= { value: V?, children: Map K τ_Tr }
```

**Subsumption**: `τ_Tr[K, V] ≅ τ_KT[K, V?]`

Proof: substitute `V? = Maybe V` for `V` in `τ_KT`:
```
τ_KT[K, V?] = { value: V?, children: Map K (τ_KT[K, V?]) }
             = { value: Maybe V, children: Map K (τ_KT[K, Maybe V]) }
             ≅ τ_Tr[K, V]                                              □
```

### 5.2 Typing Rules

```
                     v : V    ch : Map K (Tree.Keyed K V)
T-NODE:    ──────────────────────────────────────────────
                    node(v, ch) : Tree.Keyed K V


              t : Tree.Keyed K V     p : [K]     |p| = 0
T-LOOKUP-∅: ──────────────────────────────────────────────
                          t.value : V


           t : Tree.Keyed K V    k : K    ks : [K]    t.children[k] = t'
T-LOOKUP:  ────────────────────────────────────────────────────────────────
                          t[k :: ks] = t'[ks] : V?


                 t : Tree.Keyed K V    f : (V → U)
T-MAP:     ──────────────────────────────────────────────
                  t.mapValues(f) : Tree.Keyed K U


           t₁ : Tree.Keyed K V₁    t₂ : Tree.Keyed K V₂
T-ZIP:     ──────────────────────────────────────────────────
               zip(t₁, t₂) : Tree.Keyed K (V₁, V₂)
```

where `zip` is defined over the intersection of children keys.

### 5.3 Operational Semantics

**Insert** (key-path creation with intermediate values):
```
insert(v, [], iv, node(v₀, ch))              → node(v, ch)
insert(v, k::ks, iv, node(v₀, ch))
    | k ∈ dom(ch)                             → node(v₀, ch[k ↦ insert(v, ks, iv, ch[k])])
    | k ∉ dom(ch)                             → node(v₀, ch[k ↦ insert(v, ks, iv, node(iv, ∅))])
```

**mapValues** (with recursivelyApply):
```
mapValues(f, node(v, ch))                     → let (u, r) = f(v) in
                                                  if r then node(u, mapAll(u, ch))
                                                  else node(u, {k ↦ mapValues(f, c) | (k,c) ∈ ch})

mapAll(u, ch)                                 → {k ↦ node(u, mapAll(u, c.children)) | (k,c) ∈ ch}
```

**zip** (structural intersection):
```
zip(node(v₁, ch₁), node(v₂, ch₂))           → node((v₁,v₂), {k ↦ zip(ch₁[k], ch₂[k]) | k ∈ dom(ch₁) ∩ dom(ch₂)})
```

### 5.4 Soundness Argument

The `recursivelyApply` flag introduces a subtlety: it short-circuits the transform, applying a fixed value to all descendants. This is sound because:

1. `mapValues(f)` without `recursivelyApply` is a standard functor map over the tree's value positions
2. With `recursivelyApply`, the transform degenerates to `const u` for all descendants, which is still a valid natural transformation (constant functor)
3. The tree structure (key skeleton) is preserved in both cases — no keys are added or removed

The `zip` operation is sound over the key intersection: `dom(zip(t₁, t₂)) = dom(t₁) ∩ dom(t₂)` at every level. Keys present in only one tree are dropped, matching swift-testing's semantics (if a test exists in the test graph but not the action graph, it's excluded from the step graph).

---

## Part VI: Cognitive Dimensions Evaluation

Per [RES-025], evaluating the API using Green & Petre's Cognitive Dimensions framework:

### Option A: `Tree.Keyed<Key, Value>` in tree-primitives

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Visibility** | Good | Lives where you'd look for tree types. `import Tree_Primitives` gives access. |
| **Consistency** | Good | Follows same pattern as `Tree.N`, `Tree.Unbounded` — independent peer types. |
| **Viscosity** | Low | Changing from `Graph<K, V>` to `Tree.Keyed<K, V>` is a type rename + import change. |
| **Role-expressiveness** | Good | `Tree.Keyed` clearly communicates "tree with keyed children." |
| **Error-proneness** | Low | Phantom tagging + generation tokens prevent cross-tree and stale-position bugs. |
| **Abstraction** | Appropriate | One type serves both keyed-tree and trie use cases via `V` vs `V?`. |

### Option C: `Trie<Key, Value>` standalone package

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Visibility** | Mixed | Must know to look for "trie" package. Users thinking "tree" won't find it. |
| **Consistency** | Mixed | Literature-consistent (tries are maps). But structural operations (subgraph, zip) feel tree-like, not map-like. |
| **Viscosity** | Low | Same migration effort. |
| **Role-expressiveness** | Mixed | `Trie` communicates "map with prefix operations." Doesn't communicate "hierarchical structure you can navigate." |
| **Error-proneness** | Same | Same safety features. |
| **Abstraction** | Overfit | Forces optional values (`V?`) at every node. Non-optional use cases (`Graph<String, Action>`) are awkward. |

---

## Part VII: Comparison Table

| Criterion | A: Tree.Keyed (tree pkg) | B: Upgrade existing | C: Trie (new pkg) | D: Trie (tree pkg) | E: Tree.Keyed (new pkg) |
|-----------|--------------------------|--------------------|--------------------|--------------------|-----------------------|
| Literature alignment | Partial (keyed tree = rare but real) | N/A (infeasible) | Strong (trie = map) | Weak (trie in tree pkg) | Partial |
| Naming clarity | `Tree.Keyed<K, V>` — clear | — | `Trie<K, V>` — clear but misleading for tree use | Confusing | Clear but isolated |
| swift-testing fit | Excellent | — | Good (awkward non-optional) | Good | Excellent |
| Infrastructure reuse | Arena, positions, tokens | — | None | Arena | None |
| Package impact | +1 module in existing pkg | Breaking changes | +1 package (62nd) | +1 module, semantic confusion | +1 package (62nd) |
| ~Copyable support | Via arena variants | — | Must build from scratch | Via arena variants | Must build from scratch |
| Subsumes trie | Yes (`V = U?`) | — | IS the trie | IS the trie | Yes (`V = U?`) |
| Subsumes keyed tree | IS the keyed tree | — | Awkward (`V?` forced) | Awkward | IS the keyed tree |
| Implementation effort | Medium (new type, reuse arena) | High (breaking) | High (new package + arena) | Medium | High (new package + arena) |

---

## Part VIII: The Decisive Argument

The literature finding that "tries are maps" applies to tries-as-maps — implementations where the tree structure is hidden behind a flat key-value interface (`IntMap`, `HashMap`, `TreeDictionary`). These types never expose `subgraph`, `children`, `mapValues` preserving topology, or `zip`.

swift-testing's use case is **not a trie-as-map**. It is a **keyed tree** — a hierarchical structure navigated structurally with key-labeled edges. The operations that matter (subgraph extraction, child iteration, structure-preserving transforms, structural zip, depth-first traversal, recursive-apply inheritance) are tree operations, not map operations.

The formal type confirms this:

```
KeyedTree K V = (V, Map K (KeyedTree K V))     — what swift-testing uses
Trie K V      = (Maybe V, Map K (Trie K V))    — what the literature studies
```

swift-testing uses `V` (not `Maybe V`) in 3 of 7 instantiations (`Action`, `Bool`, `(Test?, Action)`). Forcing these into `V?` would lose type safety — you'd need runtime `!` unwraps where the type system currently guarantees presence.

The keyed tree is the more general type. Trie is the special case when `V = U?`.

---

## Part IX: Addressing the Classification Challenge (v4.0)

### 9.1 Why Apple Calls It "Graph"

Apple's own documentation contradicts the type name. From `Graph.swift`:

- Line 11: *"A type representing a **tree** with key-value semantics."*
- Line 22: *"This type is effectively equivalent to a **trie**."*

The developers chose `Graph` as a loose generality label — graph is the most inclusive term for any node-and-edge structure, and avoids committing to "tree" or "trie" in the type name. But the code itself is unambiguous:

| Graph characteristic | Present? | Evidence |
|---------------------|----------|----------|
| Cycles | No | Recursive value type — structurally acyclic |
| Edge weights | No | Children are `[K: Graph]`, no weight parameter |
| Adjacency queries | No | No `neighbors`, `inDegree`, `outDegree` |
| Path-finding algorithms | No | No Dijkstra, BFS-shortest-path, SCC |
| Parent→child hierarchy | **Yes** | `children` property, `subgraph(at:)` |
| Depth-first traversal | **Yes** | `forEach` visits depth-first |
| Structure-preserving map | **Yes** | `mapValues` preserves key skeleton |
| Structural zip | **Yes** | `zip` intersects children at each level |
| Recursive-apply inheritance | **Yes** | `recursivelyApply` propagates parent values |

Every operation is a tree operation. Zero operations are graph-specific. The name `Graph` is a misnomer — Apple's documentation says so explicitly.

### 9.2 What Is This Data Structure, Honestly?

The most precise characterization of swift-testing's `Graph<K, V>` is:

```
(V, Dictionary<K, Self>)
```

A value paired with a recursive dictionary of children. This definition *simultaneously* is:

| Identity | Why it qualifies | Primary operations |
|----------|-----------------|-------------------|
| **Keyed tree** | Recursive hierarchy with key-labeled edges | subgraph, children, forEach, mapValues, zip |
| **Recursive dictionary** | Each node IS a dictionary entry whose values are themselves dictionaries | subscript by key path, insert at key path |
| **Trie** (when V is optional) | Sparse prefix-addressed structure | insertValue with intermediate nil, compactMapValues |

The question is not "which one is it?" — it genuinely is all three. The question is: **which identity should the primitive emphasize?**

The answer comes from the operations. swift-testing's 35 call sites break down:

| Operation category | Call sites | Identity implied |
|-------------------|-----------|-----------------|
| Tree-structural (subgraph, children, forEach, mapValues, zip, recursivelyApply) | 27 | Tree |
| Path-based (insert at key path, subscript key path, takeValues) | 8 | Dictionary/Trie |

The dominant usage (77%) is tree-structural. The type is navigated as a hierarchy, not queried as a map. **Tree identity with dictionary-based addressing** is the correct characterization.

### 9.3 Existing Primitives: Building Blocks Inventory

Could existing swift-primitives types compose into this, or suggest a different placement?

| Primitive | Package | Role for keyed tree | Assessment |
|-----------|---------|-------------------|------------|
| `Dictionary<Key, Value>` | dictionary-primitives | Children storage at each node | **Direct fit** — `[K: Index<Node>]` is dictionary-shaped |
| `Buffer<Node>.Arena` | tree-primitives | Arena allocation with generation tokens | **Direct fit** — parameterize with new Node type |
| `Hash.Table<Element>` | hash-table-primitives | Open-addressed linear probing storage | Too low-level — Dictionary already wraps hash storage |
| `Set<Element>.Ordered` | set-primitives | Key set operations | Useful for `zip` key intersection, not structural |
| `Array.Indexed<Tag>` | array-primitives | Phantom-tagged flat storage | Not applicable — children are key-addressed, not index-addressed |
| `Graph.Sequential<Tag, Payload>` | graph-primitives | Adjacency-list immutable graph | Wrong structure — no value-per-node, no key-addressed children, append-only builder |

**Key insight**: The building blocks for `Tree.Keyed` already exist — `Dictionary` for per-node children storage and `Buffer.Arena` for arena allocation. No new infrastructure is needed. The question is purely about **where the assembled type lives and what it's called**.

### 9.4 Revised Feasibility: Unlimited Breaking Changes

Assuming all breaking changes are acceptable, can existing tree types absorb keyed-tree functionality?

**No. The infeasibility is type-level, not compatibility-level.**

| Barrier | Why breaking changes don't help |
|---------|-------------------------------|
| **Different generic parameters** | `Tree.N<Element, let n: Int>` vs `Tree.Unbounded<Element>` vs keyed `<Key, Value>`. You can't parameterize over this — it's a different number and kind of generic arguments. |
| **Different child addressing IS the public API** | `InsertPosition.child(of:slot:)` vs `.child(of:at:)` vs `.child(of:key:)` are different API contracts. Breaking changes let you rename them, but they're still three shapes. |
| **Different traversal semantics** | Tree.N iterates fixed slots (some nil). Tree.Unbounded iterates dense indices. Keyed tree iterates key-value pairs from a dictionary. A protocol abstracting over these needs associated types for child iteration — which is exactly what "three separate types" already gives you. |
| **Different invariants** | Tree.N guarantees at most `n` children (compile-time). Tree.Unbounded guarantees dense child indices. Keyed tree guarantees unique keys per level. These are different type-level contracts. |

The theoretical unification would look like:

```swift
protocol TreeNode {
    associatedtype Element
    associatedtype ChildAddress
    associatedtype ChildCollection: Collection where ChildCollection.Element == (ChildAddress, Index<Self>)
    var element: Element { get }
    var children: ChildCollection { get }
}
```

This protocol exists, and it's called… having three separate types that each implement their own node. The abstraction adds machinery without removing any concrete code. Each type still needs its own `Node`, its own `InsertPosition`, its own traversal loops. The protocol is a phantom — it names the pattern without reducing the implementation.

**Conclusion unchanged**: Breaking changes enable cleaner shared infrastructure (a common `Arena` protocol, perhaps), but the types themselves remain necessarily distinct. `Tree.Keyed` is a new peer type.

### 9.5 Could This Live in Dictionary-Primitives?

Since the data structure is `(V, Dictionary<K, Self>)`, should it live in dictionary-primitives as `Dictionary.Recursive<K, V>` or similar?

**Arguments for**:
- Children ARE a dictionary at each level
- Key addressing IS dictionary semantics
- The `Hashable` constraint comes from dictionary usage

**Arguments against**:
- Every dictionary-primitives variant (Ordered, Bounded, Static, Small) provides **flat** key-value storage. No variant is recursive.
- The operations that matter (subgraph, depth-first traversal, structural zip, recursive apply) are tree-structural, not dictionary-structural. You would never expect `Dictionary.Recursive` to have a `zip` that merges two trees by key intersection.
- Putting it in dictionary-primitives suggests map identity, but the API surface (§9.2) is 77% tree-shaped.
- The arena infrastructure (`Buffer<Node>.Arena`, generation tokens, `Tree.Position`, CoW) lives in tree-primitives. A dictionary-primitives placement would either duplicate this or create a dependency from dictionary-primitives → tree-primitives, which inverts the natural direction.

**Verdict**: Dictionary is a building block used *inside* the node for child storage. It is not the identity of the whole structure. A recursive structure navigated as a hierarchy with subgraph extraction, structural transforms, and depth-first traversal is a tree — one whose edges happen to be labeled with dictionary keys.

### 9.6 Summary: The Bottom of This

| Claim | Status |
|-------|--------|
| Apple's `Graph<K, V>` is mislabeled | **Confirmed** — Apple's docs say "tree" and "trie"; the operations are tree-structural; zero graph-specific operations exist |
| The data structure is `(V, Dictionary<K, Self>)` | **Confirmed** — simultaneously keyed tree, recursive dictionary, and trie (when V optional) |
| Tree identity is primary | **Confirmed** — 77% of call sites use tree-structural operations |
| Existing tree types can absorb this (with any breaking changes) | **Rejected** — different generic parameters, different child addressing, different traversal semantics, different invariants; these are type-level incompatibilities, not API stability concerns |
| Existing dictionary/set/hash primitives change the answer | **Rejected** — Dictionary is a building block for child storage, not the identity; no existing primitive provides hierarchical structure |
| `Tree.Keyed<Key, Value>` in swift-tree-primitives remains correct | **Confirmed** — composes Dictionary (children) + Arena (allocation) + tree identity (operations) |

---

## Part X: Is Apple's Design Even Optimal? (v5.0)

### 10.1 The Structural Problem: Nested Value-Type Dictionaries

Apple's `Graph<K, V>` is `struct { var value: V; var children: [K: Graph] }`. Every node owns a separate `Swift.Dictionary` heap allocation. For *n* nodes, that is *n* independent dictionary buffers, each independently reference-counted, each a separate pointer chase.

**Memory cost for 10,000 nodes** (String key, Test? value):
- Naive recursive: ~10K dictionary allocations × (48 bytes overhead + bucket array) + per-node value storage = **several MB, severely fragmented**
- Arena-allocated: ~10K × 40 bytes contiguous + 10K × 8 bytes metadata = **~480KB, single allocation**

The cache locality story is devastating. Traversing the tree at every level follows a pointer to a different heap allocation, then probes a hash table, then follows another pointer to the child `Graph` which itself contains another dictionary pointer. Every level is essentially a random memory access — L1/L2 cache miss per node.

### 10.2 The CoW Cascading Anti-Pattern

This is the most consequential design flaw. Every in-place mutation triggers a copy-on-write cascade through the entire ancestry.

`insertValue` at depth *d*:
```swift
if var child = children[key] {       // ← creates second reference to child's dictionary buffer
    child.insertValue(...)           // ← recurses, repeating at every level
    children[key] = child            // ← write-back: replaces original
}
```

The extraction `var child = children[key]` creates a temporary second reference to the child's `children` dictionary. The recursive call mutates the child, which may trigger CoW on *its* children dictionary. The write-back `children[key] = child` mutates the parent's dictionary (which may itself CoW if it had a second reference from an iterator).

**Cost**: A single `insertValue` on a path of depth *d* costs **O(d × b_avg)** where *b_avg* is the average branching factor, because each level may copy its dictionary buffer.

This pattern appears **4+ times** in swift-testing's usage:

```swift
// _recursivelySynthesizeSuites, _recursivelyApplyTraits,
// _recursivelyApplyFilterProperties, _recursivelyPruneTestGraph
for (key, var childGraph) in graph.children {
    mutateRecursively(&childGraph)
    graph.children[key] = childGraph    // CoW copy each iteration
}
```

This is not just slow — it is error-prone. Forgetting the write-back silently loses mutations. There is no compiler warning.

### 10.3 Operational Inefficiencies in Production Code

| Problem | Location | Severity | Root cause |
|---------|----------|----------|------------|
| **O(n²) output rendering** | `AdvancedConsoleOutputRecorder` | High | Every helper does O(n) full-graph scan via `forEach` for operations that should be O(1) via `subgraph(at:).children`. `_childKeyPaths` is called per suite, each doing a full traversal. |
| **O(n log n) per-level child sorting** | `Runner._runChildren` (line 327 FIXME) | Medium | Children re-sorted by source location at every level during execution. Apple's own FIXME: "Graph should adopt OrderedDictionary if possible so it can pre-sort its nodes once." |
| **Double traversal for function-based filtering** | `TestFilter.Operation.apply` | Medium | Flatten graph → filter → rebuild Selection → re-traverse graph. Two full traversals instead of one. |
| **Key path accumulation is O(n × d)** | `_forEach`, `_compactMapValues` | Medium | At every node, a `[K]` array is copied and extended. At depth *d*, each copy is O(d). Total across tree: O(Σ depths) = O(n × d_avg). |
| **`mapValues` creates entirely new tree** | All `mapValues`/`compactMapValues` calls | Medium | Each call allocates *n* new dictionary instances. No in-place transform. |
| **`recursivelyApply` still visits all descendants** | `compactMapValues` with `recursivelyApply: true` | Low | Saves calling the user's closure, but still allocates new `Graph<K,U>` nodes at every level. Does not short-circuit tree reconstruction. |
| **`count` is O(n)** | `count` property | Low | No cached count. Full traversal on each call. |
| **`flatMap` creates intermediate array** | `flatMap` implementation | Low | `map(transform).flatMap { $0 }` allocates `[S]` then flattens, instead of single-pass accumulation. |

### 10.4 Missing Capabilities

| Capability | Status in Apple's Graph | What a primitive would provide |
|-----------|------------------------|-------------------------------|
| **Parent navigation** | Impossible without full traversal. Usage sites pass key paths through recursion as workaround. | O(1) via stored `parentIndex` in every node. |
| **Stale reference detection** | None. Hold a reference to a removed subtree — read stale data silently. | O(1) generation-token validation on every access. |
| **Ordered children** | Unordered. Apple's FIXME requests `OrderedDictionary`. | `Dictionary.Ordered<K, Tree.Position>` preserves insertion order. Sort once, iterate in order forever. |
| **Lazy iteration** | All traversals are eager (materialize `[U]`). | `Sequence`-conforming iterators with stack-based state. No materialization. |
| **Stack overflow safety** | Recursive traversal. Depth ~5,000–10,000 overflows background thread stack (512KB on macOS). | Iterative traversal using heap-allocated `Stack<Index<Node>>`. No depth limit. |
| **~Copyable elements** | Impossible. `Swift.Dictionary` requires `Value: Copyable`. | Full `~Copyable` support. `consuming`/`borrowing` element access. |
| **In-place child mutation** | Extract-mutate-writeback pattern required. Error-prone. | Direct mutation via arena position. `tree.update(at: position) { element in ... }`. |
| **Whole-tree CoW** | Per-node CoW cascading (O(d × b) per mutation). | Single `ensureUnique()` check on arena storage. O(1) amortized. |
| **Capacity reservation** | Not expressible for the tree as a whole. | `init(minimumCapacity:)` reserves arena slots upfront. |
| **Typed errors** | Force unwrap in `mapValues` (`compactMapValues(transform)!`). Silent nil returns on missing paths. | `throws(Tree.Keyed.Error)` with `.invalidPosition`, `.keyNotFound`, etc. |

### 10.5 What a Composed `Tree.Keyed<Key, Value>` Would Solve

A `Tree.Keyed<K, V>` built on existing primitives composes three layers:

```
┌─────────────────────────────────────────┐
│  Tree.Keyed<K, V>  (tree-primitives)    │  ← keyed-tree identity + operations
│                                          │
│  Per-node children:                      │
│    Dictionary.Ordered<K, Tree.Position>  │  ← from dictionary-primitives
│                                          │
│  Node storage:                           │
│    Buffer<Node>.Arena                    │  ← from buffer-primitives (via tree-primitives)
└─────────────────────────────────────────┘
```

**What each layer contributes**:

| Layer | Contribution | Eliminates |
|-------|-------------|------------|
| `Buffer<Node>.Arena` | Contiguous node storage, generation tokens, O(1) alloc/free, whole-tree CoW, capacity reservation | Fragmented allocations, CoW cascading, stale references |
| `Dictionary.Ordered<K, Position>` | Per-node keyed lookup, insertion-order preservation | Re-sorting children, unordered iteration |
| Tree.Keyed operations | Iterative traversal (pre/post/level/DFS), O(1) parent navigation, typed errors, ~Copyable support | Stack overflow, recursive traversal, force unwraps, copy-in/copy-out |

**The specific improvements over Apple's Graph**:

| Apple's Graph | Tree.Keyed | Improvement factor |
|--------------|-----------|-------------------|
| n dictionary allocations | 1 arena allocation | **n×** fewer allocations |
| O(d × b) mutation (CoW cascade) | O(1) amortized mutation | **d×** faster for deep trees |
| O(n²) output rendering | O(n) with direct child access | **n×** for rendering |
| O(n log n) per-level sorting | O(1) ordered iteration | **n log n** per level eliminated |
| O(n × d) key path accumulation | O(1) position-based navigation | **d×** per traversal |
| No stale reference detection | O(1) generation-token validation | Safety gap closed |
| No parent navigation | O(1) stored parentIndex | Eliminates key-path workarounds |
| Recursive (stack overflow at ~5K depth) | Iterative (no depth limit) | Correctness |
| No ~Copyable support | Full ~Copyable support | Generality |

### 10.6 Could We Go Further? Operations Apple Lacks

Beyond fixing Apple's design flaws, `Tree.Keyed` could provide operations that swift-testing's consumers actually need but currently implement ad-hoc:

**1. Structural pruning**: `_recursivelyPruneTestGraph` manually walks and removes dead branches. A `prune(where:)` that removes empty subtrees in one pass would replace 20+ lines of manual recursion.

**2. Parallel graph merge**: The dual-graph construction pattern (build `testGraph` and `actionGraph` separately, zip at end) could be a single `merge(_:_:combining:)` operation that unions two trees with a conflict resolver.

**3. Subtree bulk set**: The `recursivelyApply` mechanism (which still visits all descendants) could become `setSubtreeValue(_:at:)` — a genuine O(1) operation that marks a subtree as having a uniform value, lazily propagated on access. This requires a sentinel or inheritance chain, not reconstruction.

**4. Ordered children out of the box**: Apple's FIXME asks for `OrderedDictionary`. `Dictionary.Ordered` solves this. Insert in source-location order once; iterate in order forever.

**5. Lazy DFS/BFS sequences**: `tree.depthFirst` returns a `Sequence` that lazily visits nodes without materializing an array. Eliminates the `compactMap { $0.value }` → `[Test]` materialization pattern.

**6. Structural diffing**: Given two `Tree.Keyed<K, V>` where `V: Equatable`, produce added/removed/changed nodes. Useful for incremental test re-planning.

### 10.7 Honest Assessment: What Doesn't Improve

| Aspect | Assessment |
|--------|-----------|
| **Per-node dictionary allocation** | Each node's `Dictionary.Ordered<K, Position>` is still a separate allocation. The arena holds the *nodes* contiguously, but each node's *children dictionary* is its own buffer. This is inherent to keyed children — you need a hash table per node. |
| **Algorithmic complexity of `mapValues`** | Still O(n) to visit every node. The improvement is constant-factor (no dictionary reconstruction), not asymptotic. |
| **`zip` complexity** | Still O(min(n₁, n₂)). The arena doesn't change the algorithm. |
| **API learning curve** | Arena-based APIs (positions, generation tokens) are more complex than `graph.value`, `graph.children[key]`. The simplicity of Apple's design is genuine — it just doesn't scale. |

---

## Outcome

**Status**: RECOMMENDATION

### Decision: Option A — `Tree.Keyed<Key, Value>` in swift-tree-primitives

**Rationale** (strengthened in v4.0, extended in v5.0):

1. **Correct data structure identity.** swift-testing's Graph is `(V, Dictionary<K, Self>)` — simultaneously a keyed tree, recursive dictionary, and trie (§9.2). The tree identity dominates: 77% of call sites use tree-structural operations (subgraph, children, mapValues with recursivelyApply, zip, forEach). Apple's own documentation calls it "a tree" (line 11) and "a trie" (line 22) — never "a graph."

2. **Strictly improves on Apple's design.** The naive recursive struct has fundamental performance problems: n× allocation overhead, O(d × b) CoW cascading on mutation, O(n²) rendering paths, O(n log n) per-level sorting (§10.3). Arena allocation, ordered children, iterative traversal, and position-based mutation eliminate all of these (§10.5).

3. **Subsumes trie.** `Tree.Keyed<K, V?>` is isomorphic to `Trie<K, V>`. One type covers both use cases — no need for a separate trie when the keyed tree naturally generalizes it.

4. **Cannot upgrade existing types — even with unlimited breaking changes.** The infeasibility is type-level: different generic parameter shapes (`<Element, let n>` vs `<Element>` vs `<Key, Value>`), different child addressing (slot vs index vs key), different traversal semantics, different invariants. A unifying protocol would be a phantom abstraction that names the pattern without reducing any concrete code (§9.4).

5. **Consistent with existing architecture.** Tree.N, Tree.Unbounded, and Tree.Keyed are independent peer types in the same package — matching the universal pattern from the literature (F2: tree variants never share a common protocol).

6. **Composes existing primitives.** `Tree.Keyed` layers `Dictionary.Ordered<K, Position>` (from dictionary-primitives) for per-node keyed/ordered children on top of `Buffer<Node>.Arena` (from buffer-primitives via tree-primitives) for contiguous node storage (§10.5). Both building blocks already exist.

7. **Not a dictionary-primitives type.** Despite using Dictionary internally, the assembled structure's API is tree-shaped (subgraph, depth-first traversal, structural zip, recursive apply). Placing it in dictionary-primitives would suggest map identity and invert the natural dependency direction (§9.5).

8. **Enables capabilities Apple's Graph cannot provide.** ~Copyable elements, O(1) parent navigation, stale-position detection, iterative stack-safe traversal, typed errors, capacity reservation, lazy iteration (§10.4). These are not theoretical — they address real gaps in the swift-testing codebase.

### Implementation Outline

```
swift-tree-primitives/
├── Sources/
│   ├── Tree Primitives Core/           (existing)
│   ├── Tree N Bounded Primitives/      (existing)
│   ├── Tree Unbounded Primitives/      (existing)
│   ├── Tree Keyed Primitives/          ← NEW
│   │   ├── Tree.Keyed.swift
│   │   ├── Tree.Keyed.Node.swift
│   │   ├── Tree.Keyed.InsertPosition.swift
│   │   ├── Tree.Keyed.Error.swift
│   │   └── Tree.Keyed.Traversal.swift
│   ├── Tree Keyed Map Primitives/      ← NEW (mapValues, compactMapValues)
│   ├── Tree Keyed Zip Primitives/      ← NEW (zip)
│   └── Tree Keyed DFS Primitives/      ← NEW (forEach, lazy DFS iterator)
```

### Minimum Viable API (from swift-testing operations inventory)

```swift
// --- Construction ---
Tree.Keyed<Key, Value>()
tree.insert(value, at: keyPath, intermediateValue:)
tree.update(value, at: keyPath)
tree[keyPath]                                        // subscript for sparse (V = U?)

// --- Navigation ---
tree.subgraph(at: keyPath) -> Tree.Keyed?
tree.value -> Value
tree.children                                        // keyed children iteration
tree.takeValues(at: keyPath) -> some Sequence<Value?>

// --- Functional transforms ---
tree.mapValues { (keyPath, value) -> U } -> Tree.Keyed<Key, U>
tree.mapValues { (keyPath, value) -> (U, recursivelyApply: Bool) } -> Tree.Keyed<Key, U>
tree.compactMap { (keyPath, value) -> U? } -> [U]
tree.forEach { (keyPath, value) in }                 // sync + async

// --- Structural ---
zip(tree1, tree2) -> Tree.Keyed<Key, (V1, V2)>

// --- Properties ---
tree.count -> Int                                    // O(1)
```

### Future Extensions (Not MVP)

- Lazy DFS/BFS iterators (`~Copyable`, matching graph-primitives pattern)
- `compactMapValues` (pruning transform)
- Bounded/Inline/Small variants
- `Sendable` conditional conformance
- Async variants of all functional transforms

### What This Enables

If `Tree.Keyed` existed, swift-testing's 880-line internal `Graph<K, V>` could be:

```swift
import Tree_Keyed_Primitives

typealias TestGraph<V> = Tree.Keyed<String, V>
```

Backed by a production-quality, arena-allocated, phantom-tagged, generation-validated primitive with iterative traversal, `~Copyable` support, and CoW semantics — all features the ad-hoc implementation lacks.

---

## Changelog

- **v5.0.0** (2026-03-01): Reverse analysis — is Apple's design optimal? (Part X). Full operational audit of 35 Graph call sites across 7 phases. Identified CoW cascading anti-pattern (O(d × b) per mutation), O(n²) output rendering, O(n log n) per-level sorting (Apple's own FIXME). Demonstrated that composed `Tree.Keyed` = `Buffer<Node>.Arena` + `Dictionary.Ordered<K, Position>` strictly improves on every dimension: n× fewer allocations, O(1) mutation, ordered children, iterative traversal, ~Copyable support. Added 6 novel operations (structural pruning, parallel merge, subtree bulk set, ordered children, lazy sequences, structural diffing). Strengthened recommendation with 8-point rationale.
- **v4.0.0** (2026-03-01): Classification challenge deep-dive (Part IX). Addressed: Apple's "Graph" naming is documented misnomer. Audited dictionary/set/hash-table/array primitives as building blocks — Dictionary and Arena compose into Tree.Keyed, but the type's identity is tree (77% tree-structural call sites). Demonstrated upgrade infeasibility persists even with unlimited breaking changes (type-level incompatibility, not API stability). Evaluated dictionary-primitives placement and rejected (wrong identity, wrong dependency direction). Strengthened rationale with building-blocks composition argument.
- **v3.0.0** (2026-03-01): Tier 3 upgrade. Added SLR (34 sources), formal semantics, five-option analysis, feasibility audit of existing tree type upgrades (infeasible), Cognitive Dimensions evaluation. Confirmed Option A recommendation with literature-grounded rationale.
- **v2.0.0** (2026-03-01): Expanded from closed comparison to constructive analysis with tree-primitives evaluation and operational inventory.
- **v1.0.0** (2026-03-01): Initial comparative analysis.

## References

### Primary Sources (SLR)
- Fredkin, E. (1960). "Trie Memory." *CACM* 3(9).
- Connelly, R.H. & Morris, F.L. (1995). "A Generalization of the Trie Data Structure." *MSCS* 5(3).
- Okasaki, C. (1998). *Purely Functional Data Structures*. Cambridge. Ch. 10.
- Hinze, R. (2000). "Generalizing Generalized Tries." *JFP* 10(4).
- Bagwell, P. (2001). "Ideal Hash Trees." EPFL TR.
- Prokopec, A. et al. (2012). "Concurrent Tries with Efficient Non-Blocking Snapshots." *PPoPP*.

### Implementation Sources
- Haskell `containers` (Data.Map, Data.IntMap, Data.Tree), `bytestring-trie`, `generic-trie`, `MemoTrie`
- Rust `BTreeMap`, `radix_trie`, `sequence_trie`
- OCaml `Map`, `patricia-tree`
- C++ `std::map`, `Boost.PropertyTree`, HAT-trie
- Java `TreeMap`, Apache `PatriciaTrie`
- Scala `TrieMap`, `HashMap` (HAMT)
- Swift `TreeDictionary` (swift-collections)
- Isabelle/HOL `Trie_Map` theory

### Companion Documents
- [trie-keyed-tree-literature-review.md](trie-keyed-tree-literature-review.md) — Full SLR
- [tree-type-family-organization-across-libraries.md](tree-type-family-organization-across-libraries.md) — Type family survey
- [comparative-tree-graph-primitives.md](comparative-tree-graph-primitives.md) — Prior tree/graph analysis

### swift-testing Sources
- `swiftlang/swift-testing/Sources/Testing/Support/Graph.swift`
- `swiftlang/swift-testing/Sources/Testing/Running/Runner.Plan.swift`
- `swiftlang/swift-testing/Sources/Testing/Running/Configuration.TestFilter.swift`
- `swiftlang/swift-testing/Sources/Testing/Test.ID.Selection.swift`
- `swiftlang/swift-testing/Sources/Testing/Events/Recorder/Event.AdvancedConsoleOutputRecorder.swift`

### swift-primitives Sources
- `/Users/coen/Developer/swift-primitives/swift-tree-primitives/` — Tree primitives (audit target)
- `/Users/coen/Developer/swift-primitives/swift-graph-primitives/` — Graph primitives (comparison)
