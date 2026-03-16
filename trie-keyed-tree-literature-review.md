# Trie and Keyed-Tree Data Structures: Systematic Literature Review

<!--
---
version: 1.0.0
last_updated: 2026-03-01
status: RECOMMENDATION
tier: 3
applies_to: [swift-tree-primitives, swift-primitives]
normative: false
depends_on: comparative-tree-graph-primitives.md
---
-->

## Context

`swift-tree-primitives` provides arena-based n-ary trees (`Tree.N`, `Tree.Unbounded`) that model structural parent/child relationships. These trees are explicitly *not* search trees — they store elements, not key-value pairs (see [comparative-tree-graph-primitives.md](comparative-tree-graph-primitives.md), Section 1.3). A natural follow-on question arises: where do *tries* — trees keyed by sequences — fit in the type-theoretic landscape? Are they trees, maps, or something else entirely? And what does the existing literature say about keyed trees more broadly — trees whose edges carry labels or keys?

This document systematically reviews the academic and implementation landscape of tries and keyed-tree structures across statically-typed languages, establishing foundations for any future `Tree.Keyed`, `Tree.Trie`, or `Map.Prefix` primitive.

**Trigger**: Tier 3 Discovery per [RES-012]. The trie's dual identity (tree vs map) and its implications for type parameter design justify deep analysis per [RES-020].

**Scope**: Ecosystem-wide per [RES-002a] — the classification decision (tree family vs map family) constrains naming, module placement, and API layering.

---

## Research Questions

- **RQ1**: How do type-safe languages represent tries/prefix-trees? What type parameters do they use?
- **RQ2**: Do typed trie implementations treat the trie as a tree variant or as a standalone data structure?
- **RQ3**: What is the relationship between tries, maps/dictionaries, and trees in type-theoretic literature?
- **RQ4**: What representations exist for keyed trees (trees with labeled/keyed edges)?

---

## Part I: Systematic Literature Review

### Protocol

Following Kitchenham & Charters (2007) adapted for programming language data structure design.

**Search strategy**:
- **Databases**: ACM Digital Library, Semantic Scholar, Hackage, crates.io, docs.rs, OCaml OPAM, Boost documentation, Java SE / Apache Commons documentation, Scala standard library
- **Keywords**: "trie", "prefix tree", "patricia tree", "radix trie", "HAMT", "hash array mapped trie", "generalized trie", "keyed tree", "labeled tree", "rose tree", "multiway tree", "concurrent trie"
- **Date range**: 1960–2026 (from Fredkin's original trie paper to current implementations)

**Inclusion criteria**:
- Directly addresses trie or keyed-tree data structures in a statically-typed language
- Provides formal type signature, implementation, or type-theoretic analysis
- From authoritative source (peer-reviewed paper, standard library documentation, widely-used package)

**Exclusion criteria**:
- Tutorial-only content without type system contribution
- Dynamically-typed implementations (Python, JavaScript) unless providing unique structural insight
- Application-specific trie usage without generalizable data structure contribution

### Search Results

| Source Category | Hits | After Screening |
|----------------|------|-----------------|
| Academic papers (ACM DL, Semantic Scholar) | 18 | 9 |
| Haskell ecosystem (Hackage, GHC) | 14 | 8 |
| Rust ecosystem (crates.io, docs.rs) | 11 | 5 |
| OCaml ecosystem (OPAM, Jane Street) | 6 | 3 |
| Java/Scala ecosystem | 8 | 4 |
| C++ ecosystem (STL, Boost) | 7 | 3 |
| Formal verification (Isabelle/HOL) | 3 | 2 |
| **Total** | **67** | **34** |

---

## Part II: Foundational Academic Literature

### Data Extraction

| Paper | Year | Venue | RQ | Key Contribution | Quality |
|-------|------|-------|-----|------------------|---------|
| Fredkin, "Trie Memory" | 1960 | CACM 3(9):490–499 | RQ1, RQ3 | Coined the term "trie" (from re**trie**val). Described a data structure storing function-argument pairs where the structure of the argument (character-by-character decomposition) determines the storage path. Explicitly framed as a *memory* structure, not a tree — though it is structurally a tree. | Seminal |
| Morrison, "PATRICIA — Practical Algorithm to Retrieve Information Coded in Alphanumeric" | 1968 | JACM 15(4) | RQ1 | Introduced path compression: nodes with only one child are merged with their parent. This is the *radix tree* / *Patricia tree* — a compressed trie. The key insight is that tries waste space on long common prefixes; compression eliminates single-child chains. | Seminal |
| Connelly & Morris, "A Generalization of the Trie Data Structure" | 1995 | MSCS 5(3):381–418 | RQ1, RQ3 | Generalized tries from string-indexed lookup to term-indexed lookup over arbitrary signatures. **Central theorem**: "Trie" (for any fixed signature) is a *functor*, and the corresponding lookup function is a *natural isomorphism*. The construction is parametric in the value type — the recursion defining tries appeals from one value type to others. This is the first formal treatment of the type-theoretic status of tries. | Foundational |
| Okasaki, *Purely Functional Data Structures*, Ch. 10 | 1998 | Cambridge UP | RQ1, RQ3 | Presented tries as a special case of finite maps where the key has exploitable structure. A trie over lists of characters is `Map [Char] v`, but the trie representation exploits `[Char]`'s recursive structure to decompose the map into nested maps: `Map [Char] v ≅ (Maybe v, Map Char (Map [Char] v))`. This recursive unfolding is the definitional essence of a trie. | Foundational |
| Okasaki & Gill, "Fast Mergeable Integer Maps" | 1998 | Workshop on ML | RQ1, RQ2 | Implemented finite maps over `Int` keys as big-endian Patricia trees. Framed this as *a trie on the bit representation of integers*. Showed that merge (union) is dramatically faster than balanced BSTs. Became the basis for Haskell's `Data.IntMap`. Key insight: IntMap is classified as a **map** in the containers library, even though its internal structure is a trie (Patricia tree). | High |
| Hinze, "Generalizing Generalized Tries" | 2000 | JFP 10(4):327–351 | RQ1, RQ3 | Defined tries generically for arbitrary datatypes of first-order kind. **Central isomorphism**: tries correspond to the *laws of exponents* applied to type structure. If we read `a -> b` as `b^a`, then the three laws — `b^1 ≅ b`, `b^(a₁+a₂) ≅ b^a₁ × b^a₂`, `b^(a₁×a₂) ≅ (b^a₂)^a₁` — yield the trie decomposition. A trie for type `T` is derived mechanically from `T`'s structure: sums become products, products become nesting, units disappear. Implementation requires nested datatypes, polymorphic recursion, and rank-2 types. | Foundational |
| Bagwell, "Ideal Hash Trees" | 2001 | EPFL Tech Report | RQ1 | Introduced the Hash Array Mapped Trie (HAMT). Key innovation: a 32-bit bitmap at each node indicates which of 32 possible children exist, followed by a compact array whose length equals `popcount(bitmap)`. This achieves near-hash-table speed with dramatically less memory. Insert/search/delete are O(1) amortized (bounded by hash width W, typically 32 or 64 bits). Became the basis for Clojure's persistent maps and Scala's `HashMap`. | Foundational |
| Prokopec, Bronson, Bagwell & Odersky, "Concurrent Tries with Efficient Non-Blocking Snapshots" | 2012 | OOPSLA (PPoPP) | RQ1, RQ2 | Introduced the Ctrie: a non-blocking concurrent HAMT with O(1) atomic snapshots. Uses three node types — **CNode** (branching, bitmap-indexed), **INode** (indirection, CAS target), **SNode** (single key-value) — plus **TNode** (tomb) for deletion. Lock-free snapshots enable linearizable size/iterator/clear. Classified as a **concurrent map** in Scala's collections, despite being structurally a trie. | High |
| Elliott, "Elegant Memoization with Functional Memo Tries" | 2009 | Blog/MemoTrie package | RQ3 | Built on Hinze's isomorphisms to implement memoization via the `HasTrie` type class, where `trie :: (a → b) → (a :→: b)` and `untrie :: (a :→: b) → (a → b)` form an isomorphism. `memo = untrie . trie`. A trie **is** a memoized function — the isomorphism between `a → b` and `Trie a b` is exact. | High |

### Key Synthesis from Academic Literature

**The Hinze-Connelly-Morris theorem**: A trie for a type `K` is a *functor* from the category of value types to itself, defined by structural recursion on `K`. The lookup function `lookup : K → Trie K V → Maybe V` is a *natural isomorphism* between `K → Maybe V` (functions) and `Trie K V` (data). This means:

> **A trie is simultaneously a tree (by structure) and a map (by semantics). It is not reducible to either.**

The exponent-law derivation makes this precise:

| Key type `K` | Trie derivation `Trie K V` | Rule |
|-------------|---------------------------|------|
| `Void` (0) | `()` (unit) | `V^0 = 1` |
| `()` (1) | `V` | `V^1 = V` |
| `Bool` (2) | `(V, V)` | `V^2 = V × V` |
| `Either A B` (A + B) | `(Trie A V, Trie B V)` | `V^(A+B) = V^A × V^B` |
| `(A, B)` (A × B) | `Trie A (Trie B V)` | `V^(A×B) = (V^B)^A` |
| `[A]` (μX. 1 + A×X) | `μT. (Maybe V, Trie A T)` | Recursive unfolding |

The last row is the classical string trie: a `Maybe V` (value at this node) paired with a map from the next element type `A` to sub-tries.

---

## Part III: Language-by-Language Implementation Survey

### 3.1 Haskell

Haskell has the richest trie ecosystem, reflecting its community's interest in type-theoretic data structures.

#### 3.1.1 Data.Map (containers)

| Property | Detail |
|----------|--------|
| **Type** | `data Map k a = Bin !Size !k a !(Map k a) !(Map k a) \| Tip` |
| **Parameters** | `k` (key, `Ord` required), `a` (value) |
| **Internal structure** | Size-balanced binary tree (weight-balanced) |
| **Classification** | **Map** — no trie structure whatsoever |
| **Child representation** | Two children (left, right) — binary tree |
| **Complexity** | O(log n) lookup, insert, delete |
| **Structural ops** | `split`, `splitLookup` (subtree extraction), `mapKeys`, `unionWith` |
| **Relevance** | Baseline comparator. This is the "standard map" against which tries are measured. |

**Source**: [Data.Map.Strict](https://hackage.haskell.org/package/containers/docs/Data-Map-Strict.html)

#### 3.1.2 Data.IntMap (containers)

| Property | Detail |
|----------|--------|
| **Type** | `data IntMap a = Bin !Prefix !Mask !(IntMap a) !(IntMap a) \| Tip !Key a \| Nil` |
| **Parameters** | `a` (value only — key is fixed to `Int`) |
| **Internal structure** | Big-endian Patricia tree on integer bit representation |
| **Classification** | **Map** in the API, **trie** internally |
| **Child representation** | Two children per branching node (binary trie on bits) |
| **Complexity** | O(min(n, W)) where W = word size (32 or 64) |
| **Structural ops** | `union`, `intersection`, `difference` (dramatically faster than `Map` — this is the Patricia tree advantage), `mapWithKey`, `foldlWithKey'` |
| **Key insight** | IntMap is the canonical example of "trie-as-map": the API is a map, the implementation is a trie on the bit representation of `Int`. The user never sees or interacts with the trie structure. |

**Source**: [Data.IntMap.Strict](https://hackage-content.haskell.org/package/containers-0.8/docs/Data-IntMap-Strict.html); Okasaki & Gill 1998

#### 3.1.3 Data.Trie (bytestring-trie)

| Property | Detail |
|----------|--------|
| **Type** | `data Trie a` (abstract — internals not exported) |
| **Parameters** | `a` (value only — key is fixed to `ByteString`) |
| **Internal structure** | Big-endian Patricia tree on bytestring elements, then on bit representation |
| **Classification** | Described as **"an efficient implementation of finite maps from strings to values"** — explicitly a map |
| **Child representation** | Patricia-compressed; sparse branching via bit discrimination |
| **Complexity** | O(min(n, W * keyLen)) — bounded by both element count and key length |
| **Structural ops** | `match` (longest prefix match), `matches` (all prefix matches), `deleteSubmap` (remove all keys with given prefix), `submap` (extract subtrie at prefix) — these are *trie-specific* operations absent from `Data.Map` |
| **Key insight** | Despite being classified as a "map", it exposes prefix-structural operations that `Map ByteString a` cannot provide efficiently. The trie nature leaks through the map interface for operations that exploit key structure. |

**Source**: [Data.Trie](https://hackage-content.haskell.org/package/bytestring-trie-0.2.7.6/docs/Data-Trie.html)

#### 3.1.4 Data.GenericTrie (generic-trie)

| Property | Detail |
|----------|--------|
| **Type** | `type family Trie k :: * -> *` (associated type family of `TrieKey` class) |
| **Parameters** | `k` (key — any type with a `TrieKey` instance), `a` (value) |
| **Internal structure** | Derived from `k`'s `Generic` representation — follows Hinze's exponent-law derivation |
| **Classification** | **Map** — the documentation says "a map, where the keys may be complex structured data" |
| **Child representation** | Type-specific: `IntMap` for `Int` keys, `()` for `()` keys, product of tries for sum keys, nested tries for product keys |
| **Complexity** | Depends on key type structure |
| **Structural ops** | `union`, `intersection`, `difference`, `mapWithKey`, `foldWithKey` — standard map operations |
| **Key insight** | This is the Hinze isomorphism as a library. The `TrieKey` class provides the same operations as `Ord`-based `Map`, but the implementation is mechanically derived from the key type's structure. An `OrdKey` wrapper falls back to `Map` for comparison-based dispatch. This package makes explicit that **tries and maps have the same interface — the distinction is purely implementational**. |

**Source**: [Data.GenericTrie](https://hackage.haskell.org/package/generic-trie-0.3.1/docs/Data-GenericTrie.html)

#### 3.1.5 Data.HashMap (unordered-containers)

| Property | Detail |
|----------|--------|
| **Type** | `data HashMap k v = Empty \| BitmapIndexed !Bitmap !(Array (HashMap k v)) \| Leaf !Hash !(Leaf k v) \| Full !(Array (HashMap k v)) \| Collision !Hash !(Array (Leaf k v))` |
| **Parameters** | `k` (key, `Hashable` + `Eq` required), `v` (value) |
| **Internal structure** | Hash Array Mapped Trie (HAMT) — Bagwell's bitmap-compressed 32-way branching trie on hash bits |
| **Classification** | **Map** — named `HashMap`, documented as hash map |
| **Child representation** | 32-bit bitmap + compact array (popcount indexing). Five node types: Empty, BitmapIndexed (sparse), Full (dense, all 32 children present), Leaf (key-value at bottom), Collision (hash collision bucket). |
| **Complexity** | O(min(n, W/B)) ≈ O(1) amortized, where W = hash width, B = branching bits per level |
| **Key insight** | HAMT is a trie on hash bits. Like `IntMap`, the trie structure is completely hidden behind a map interface. The user interacts with it as a hash map; the trie is an implementation detail. |

**Source**: [Data.HashMap.Internal](https://hackage-content.haskell.org/package/unordered-containers-0.2.20.1/docs/Data-HashMap-Internal.html)

#### 3.1.6 Data.Tree (containers) — Rose Tree

| Property | Detail |
|----------|--------|
| **Type** | `data Tree a = Node { rootLabel :: a, subForest :: Forest a }` with `type Forest a = [Tree a]` |
| **Parameters** | `a` (node label) — **no key parameter** |
| **Internal structure** | Recursive labeled rose tree with list-of-children |
| **Classification** | **Tree** — explicitly a tree, not a map or trie |
| **Child representation** | `[Tree a]` — unkeyed list of children |
| **Key insight** | This is the standard Haskell *structural tree*. Children are identified by position in a list, not by key. There is no edge labeling. This is the closest Haskell analogue to swift-tree-primitives' `Tree.Unbounded`. |

**Source**: [Data.Tree](https://hackage.haskell.org/package/containers-0.7/docs/Data-Tree.html)

#### 3.1.7 MemoTrie (MemoTrie package)

| Property | Detail |
|----------|--------|
| **Type** | `class HasTrie a where data (:→:) a :: * → *; trie :: (a → b) → (a :→: b); untrie :: (a :→: b) → (a → b)` |
| **Parameters** | `a` (domain/key type), `b` (codomain/value type) |
| **Classification** | Neither map nor tree — the trie **is** the memoized function, and the function **is** the trie. The isomorphism `trie`/`untrie` makes this explicit. |
| **Key insight** | From the type-theoretic perspective, `a :→: b` is not "a data structure that happens to support lookup." It *is* the function `a → b`, represented as data. This is the purest expression of Hinze's exponent-law isomorphism. |

**Source**: [Data.MemoTrie](https://hackage.haskell.org/package/MemoTrie-0.6.11/docs/Data-MemoTrie.html); Elliott 2009

### 3.2 Rust

#### 3.2.1 BTreeMap (std::collections)

| Property | Detail |
|----------|--------|
| **Type** | `pub struct BTreeMap<K, V, A = Global>` |
| **Parameters** | `K` (key, `Ord` required), `V` (value), `A` (allocator) |
| **Internal structure** | B-tree (not binary tree). Each node holds B-1 to 2B-1 elements in a contiguous array. B is tuned for cache lines. |
| **Classification** | **Map** — sorted map based on comparison ordering |
| **Child representation** | Dense array of children per internal node (B-tree branching) |
| **Complexity** | O(log n) for lookup, insert, delete (with excellent cache behavior) |
| **Structural ops** | `range()`, `split_off()`, `entry()` API |
| **Key insight** | B-tree is a tree, but Rust classifies it as a *map*. The tree is an implementation detail. No structural tree navigation (parent, children, subtree) is exposed. |

**Source**: [BTreeMap](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html)

#### 3.2.2 radix_trie

| Property | Detail |
|----------|--------|
| **Type** | `pub struct Trie<K: TrieKey, V>` |
| **Parameters** | `K` (key — must implement `TrieKey`, which requires serialization to `NibbleVec`), `V` (value) |
| **Internal structure** | Radix trie (compressed) with nibble-based (4-bit) branching |
| **Classification** | Described as a **"data-structure for storing and querying string-like keys"** — positioned as its own category |
| **Child representation** | `NibbleVec` indexing — children stored in sparse representation keyed by 4-bit nibbles |
| **Complexity** | O(K) where K = key length in nibbles |
| **Structural ops** | `subtrie()` / `subtrie_mut()` — explicit subtrie extraction by prefix. Also `get_ancestor()` for longest-prefix matching. |
| **Key insight** | This crate treats tries as their own category — not "map" or "tree" but "trie". It exposes trie-specific structural operations (subtrie, ancestor) alongside map-like operations (get, insert, remove). The `TrieKey` trait requires byte serialization, fixing the key space to byte-representable types. |

**Source**: [radix_trie](https://docs.rs/radix_trie/latest/radix_trie/); [GitHub](https://github.com/michaelsproul/rust_radix_trie)

#### 3.2.3 sequence_trie

| Property | Detail |
|----------|--------|
| **Type** | `pub struct SequenceTrie<K, V, S = RandomState>` where `K: TrieKey`, `S: BuildHasher + Default` |
| **Parameters** | `K` (key fragment type — `Eq + Hash + Clone`), `V` (value), `S` (hasher for internal `HashMap`s) |
| **Internal structure** | Uncompressed trie where each node contains `Option<V>` and `HashMap<K, SequenceTrie<K, V, S>>` |
| **Classification** | Described as **"a trie-like data-structure for storing sequences of values"** — its own category |
| **Child representation** | `HashMap<K, SequenceTrie<K, V, S>>` — children are keyed by individual key-fragment values, stored in a hash map |
| **Complexity** | O(K) where K = key sequence length; each step is O(1) amortized hash lookup |
| **Structural ops** | `get_node()` (returns the subtrie at a prefix), `prefix_iter()` (iterate all descendants of a prefix) |
| **Key insight** | This is the most revealing type signature for the trie-vs-map question. The key is not `K` but `[K]` (a sequence of `K`s). The trie's children are stored in a `HashMap<K, ...>` — **a map is used to implement the trie's branching**. The trie is layered *on top of* maps. Type-theoretically: `SequenceTrie K V ≅ (Option<V>, HashMap<K, SequenceTrie K V>)`, which is exactly Okasaki's recursive trie unfolding. |

**Source**: [SequenceTrie](https://docs.rs/sequence_trie/latest/sequence_trie/struct.SequenceTrie.html)

#### 3.2.4 petgraph

| Property | Detail |
|----------|--------|
| **Type** | `pub struct Graph<N, E, Ty = Directed, Ix = DefaultIx>` |
| **Parameters** | `N` (node weight), `E` (edge weight), `Ty` (directed/undirected), `Ix` (index type) |
| **Internal structure** | Adjacency list |
| **Classification** | **Graph** — can represent trees as a special case, but no tree-specific API |
| **Key insight** | petgraph's `E` (edge weight) parameter enables labeled/keyed edges, but the library provides no trie or keyed-tree abstraction. Trees with labeled edges would be modeled as graphs with the tree invariant enforced by the user. The documentation explicitly warns: "if you need to represent a list, tree or a table and nothing else, you should never use petgraph." |

**Source**: [petgraph](https://docs.rs/petgraph/latest/petgraph/)

### 3.3 OCaml

#### 3.3.1 Map (Standard Library)

| Property | Detail |
|----------|--------|
| **Type** | Functorized: `module Make(Ord: OrderedType) : S with type key = Ord.t` |
| **Parameters** | `key` (via functor argument, requires `compare`), `'a` (value) |
| **Internal structure** | AVL tree (balanced binary tree with height tracking) |
| **Classification** | **Map** — applicative (persistent) association table |
| **Child representation** | Binary (left, right) with height balance information |
| **Complexity** | O(log n) lookup, insert, delete |

**Source**: [Map](https://ocaml.org/api/Map.html)

#### 3.3.2 patricia-tree (codex-semantics-library)

| Property | Detail |
|----------|--------|
| **Type** | `module MakeMap(Key: KEY) : MAP with type key = Key.t` — where `KEY` requires `val to_int : t -> int` |
| **Parameters** | `key` (via functor, must have injective `to_int`), `'a` (value). Heterogeneous variant: `'a key` (GADT) with `('a, 'b) value` |
| **Internal structure** | Big-endian Patricia tree, as per Okasaki & Gill 1998 |
| **Classification** | **Map** — documented as "maps and sets" with Patricia tree implementation |
| **Child representation** | Customizable via `NODE` module: `SimpleNode` (direct), `WeakNode` (weak references), `HashconsedNode` (deduplication with unique IDs) |
| **Complexity** | O(min(n, W)) where W = integer bit width |
| **Structural ops** | `idempotent_union`, `idempotent_inter` (exploiting Patricia tree stability for fast structural operations when subtrees are physically shared), `symmetric_difference`, `to_int`-based ordering |
| **Key insight** | The Patricia tree representation is *stable*: inserting nodes in any order yields the same shape. This enables identity-based short-circuiting in merge operations — if two maps share a physical subtree, the merge can skip it entirely. This is a *structural* advantage that comparison-based maps cannot match. The GADT key support (`MakeHeterogeneousMap`) enables type-safe dependent maps where different keys can map to different value types. |

**Source**: [patricia-tree](https://github.com/codex-semantics-library/patricia-tree); [OCaml package](https://ocaml.org/p/patricia-tree/0.11.0/doc/index.html)

#### 3.3.3 ptmap (Filliatre)

| Property | Detail |
|----------|--------|
| **Type** | `type 'a t` with `key = int` |
| **Parameters** | `'a` (value only — key fixed to `int`) |
| **Internal structure** | Patricia tree on integer keys |
| **Classification** | **Map** — small, focused implementation of integer maps |
| **Key insight** | Minimal implementation (~200 lines) demonstrating that Patricia trees are a natural fit for OCaml's functor system. Closer to OCaml's built-in `Map` in interface but with Patricia-tree performance characteristics for merge operations. |

**Source**: [ptmap](https://github.com/backtracking/ptmap)

### 3.4 C++

#### 3.4.1 std::map

| Property | Detail |
|----------|--------|
| **Type** | `template<class Key, class T, class Compare = less<Key>, class Allocator = allocator<pair<const Key, T>>> class map` |
| **Parameters** | `Key`, `T` (value), `Compare` (ordering), `Allocator` |
| **Internal structure** | Red-black tree (self-balancing BST) |
| **Classification** | **Map** (sorted associative container) |
| **Child representation** | Binary (left, right) with red-black coloring. Node: `_Rb_tree_node<pair<const Key, T>>` containing color, parent, left, right pointers. |
| **Complexity** | O(log n) for lookup, insert, delete |
| **Structural ops** | Iterators provide in-order traversal. `lower_bound`, `upper_bound`, `equal_range` for range queries. `extract()` (C++17) for node handle manipulation. No structural tree navigation. |
| **Key insight** | Like Rust's `BTreeMap`, the tree is an implementation detail. The interface is purely map-oriented. No user-facing concept of "left child" or "right child" exists. |

**Source**: C++ Standard [associative containers]; [MSVC internals](https://devblogs.microsoft.com/oldnewthing/20230807-00/?p=108562)

#### 3.4.2 Boost.PropertyTree

| Property | Detail |
|----------|--------|
| **Type** | `basic_ptree<Key, Data, KeyCompare>` — typically aliased as `ptree` (Key=string, Data=string) |
| **Parameters** | `Key` (edge label type), `Data` (node data type), `KeyCompare` (ordering on keys) |
| **Internal structure** | Each node: `data_type data` + `list<pair<key_type, ptree>> children` — ordered list of key-labeled children |
| **Classification** | **Tree** — explicitly a keyed tree, not a map. Documented as "a tree of values, indexed by string keys." |
| **Child representation** | `list<pair<key_type, basic_ptree>>` — **keyed children** where each edge carries a label. Children are ordered but not unique (multiple children can share the same key). |
| **Complexity** | O(n) lookup by key (linear scan of children list) |
| **Structural ops** | `get_child()`, `put_child()`, `add_child()` (allows duplicate keys), `get_value()`, path-based access with dot separators (e.g., `pt.get<int>("system.os.version")`) |
| **Key insight** | **This is the only mainstream library that models a keyed tree as a first-class concept.** Each node has both a value *and* an ordered list of keyed children. It directly supports hierarchical configuration (JSON, XML, INI) where the same key can appear multiple times. The type signature `basic_ptree<Key, Data>` has separate parameters for key and data — not `Map<[Key], Data>` (trie-as-map) but genuinely a tree where each edge has a key. |

**Source**: [Boost.PropertyTree](https://www.boost.org/libs/property_tree); [Chapter 25](https://theboostcpplibraries.com/boost.propertytree)

#### 3.4.3 HAT-trie (Tessil)

| Property | Detail |
|----------|--------|
| **Type** | `tsl::htrie_map<CharT, T>` and `tsl::htrie_set<CharT>` |
| **Parameters** | `CharT` (character type for key, typically `char`), `T` (mapped value type) |
| **Internal structure** | HAT-trie: hybrid of trie nodes (for short common prefixes) and hash table buckets (for suffix storage) |
| **Classification** | **Map/Set** — provides `prefix_range()` for prefix queries, positioned as a string map |
| **Child representation** | Trie nodes branch by character; leaf buckets are hash tables |
| **Complexity** | O(K) for lookup where K = key length; excellent cache behavior |
| **Key insight** | Practical high-performance trie for string keys. The HAT-trie hybrid approach shows that production tries often need to compromise between pure trie structure and cache-friendly hash buckets. Classified as a map with trie-specific operations (prefix search). |

**Source**: [hat-trie](https://github.com/Tessil/hat-trie)

### 3.5 Java

#### 3.5.1 TreeMap (java.util)

| Property | Detail |
|----------|--------|
| **Type** | `public class TreeMap<K,V> extends AbstractMap<K,V> implements NavigableMap<K,V>, Cloneable, Serializable` |
| **Parameters** | `K` (key, `Comparable` or via `Comparator`), `V` (value) |
| **Internal structure** | Red-black tree |
| **Classification** | **Map** (NavigableMap, SortedMap) |
| **Child representation** | Binary with red-black coloring |
| **Complexity** | O(log n) guaranteed for get, put, remove |

**Source**: [TreeMap JavaDoc](https://docs.oracle.com/javase/8/docs/api/java/util/TreeMap.html)

#### 3.5.2 PatriciaTrie (Apache Commons Collections)

| Property | Detail |
|----------|--------|
| **Type** | `public class PatriciaTrie<V> extends AbstractPatriciaTrie<String,V>` |
| **Parameters** | `V` (value only — key is fixed to `String`) |
| **Internal structure** | PATRICIA trie (compressed binary trie on bit representation of strings) |
| **Classification** | **Both Map and Trie** — implements `SortedMap<String,V>`, `Trie<String,V>`, `OrderedMap<String,V>` |
| **Child representation** | Binary Patricia tree nodes with bit-position indexing |
| **Complexity** | O(K) worst case where K = bits in largest key; O(A(K)) in practice |
| **Structural ops** | `prefixMap(String prefix)` returns a `SortedMap` view of all entries with the given prefix; `select(K key)` finds bitwise-closest entry; `selectKey()`, `selectValue()` |
| **Key insight** | Java's type hierarchy makes the dual nature explicit: `PatriciaTrie` simultaneously satisfies `SortedMap` (it is a map) and `Trie` (it has prefix operations). The `Trie` interface adds `prefixMap()` to the map contract. This is the most honest typing: a trie is a map with additional prefix-structural capabilities. |

**Source**: [PatriciaTrie](https://commons.apache.org/proper/commons-collections/apidocs/org/apache/commons/collections4/trie/PatriciaTrie.html); [Trie interface](https://commons.apache.org/proper/commons-collections/apidocs/org/apache/commons/collections4/Trie.html)

### 3.6 Scala

#### 3.6.1 TrieMap (scala.collection.concurrent)

| Property | Detail |
|----------|--------|
| **Type** | `final class TrieMap[K, V] extends AbstractMap[K, V] with Map[K, V] with MapOps[K, V, TrieMap, TrieMap[K, V]] with MapFactoryDefaults[K, V, TrieMap, Iterable] with DefaultSerializable` |
| **Parameters** | `K` (key, requires hashing), `V` (value) |
| **Internal structure** | Ctrie — concurrent hash array mapped trie. Node types: CNode (branching, 32-bit bitmap + compact array), INode (indirection for CAS), SNode (key-value leaf), TNode (tomb for deletion). |
| **Classification** | **Map** — extends `Map[K, V]` in the standard collections hierarchy. Placed in `scala.collection.concurrent`. |
| **Child representation** | 32-bit bitmap + compact array (HAMT scheme). Up to 32 children per node, sparse. |
| **Complexity** | O(log₃₂ n) ≈ O(1) amortized for lookup, insert, remove. O(1) atomic snapshot. |
| **Structural ops** | `snapshot()` (O(1) atomic), standard Map operations. No trie-specific prefix operations. |
| **Key insight** | Named "TrieMap" (acknowledging trie nature) but classified as a `Map` in the type hierarchy. The "Trie" in the name refers to the implementation strategy, not the API contract. |

**Source**: [TrieMap](https://www.scala-lang.org/api/current/scala/collection/concurrent/TrieMap.html); Prokopec et al. 2012

#### 3.6.2 HashMap (scala.collection.immutable)

| Property | Detail |
|----------|--------|
| **Type** | `final class HashMap[K, +V] extends AbstractMap[K, V] with StrictOptimizedMapOps[K, V, HashMap, HashMap[K, V]] with MapFactoryDefaults[K, V, HashMap, Iterable] with DefaultSerializable` |
| **Parameters** | `K` (key), `V` (value, covariant) |
| **Internal structure** | HAMT (compressed hash array mapped trie), based on Bagwell 2001 |
| **Classification** | **Map** — named `HashMap`, placed in immutable collections |
| **Key insight** | Scala's immutable `HashMap` is a HAMT — a trie. But like Haskell's `HashMap`, the trie nature is entirely hidden. The user sees a map; the trie is an implementation detail enabling efficient persistent (immutable) updates via structural sharing. |

**Source**: Scala 2.13 standard library

### 3.7 Formal Verification (Isabelle/HOL)

#### 3.7.1 Trie_Map Theory

| Property | Detail |
|----------|--------|
| **Type** | `datatype 'a trie3 = Nd3 bool "('a * 'a trie3) tree"` |
| **Parameters** | `'a` (alphabet type), with `bool` marking finality |
| **Internal structure** | Ternary search tree (Bentley & Sedgewick) variant — BST-based children with middle-child sub-trie |
| **Classification** | Formalized as a **Map** — the theory proves that trie operations satisfy the `Map` specification |
| **Child representation** | Binary search tree mapping alphabet elements to sub-tries |
| **Key insight** | The Isabelle formalization makes a crucial observation: "In principle, one should be able to give an implementation of tries once and for all for *any* map implementation, not just for a specific one." A trie's branching at each level is itself a map. The development works "verbatim for any map implementation" (RBT_Map, Tree_Map, etc.) except for a termination lemma. This formally confirms: **a trie is a map whose branching structure is also a map**. |

**Source**: [Theory Trie_Map](https://www.cl.cam.ac.uk/research/hvg/Isabelle/dist/library/HOL/HOL-Data_Structures/Trie_Map.html)

---

## Part IV: Cross-Cutting Analysis

### 4.1 Answering RQ1: Type Parameters for Tries

The survey reveals three dominant type parameterization patterns:

| Pattern | Type Signature | Key Parameter | Examples |
|---------|---------------|--------------|----------|
| **Fixed-key trie** | `Trie<V>` | Key is fixed (e.g., `ByteString`, `String`, `Int`) | Haskell `Data.Trie`, `IntMap`; Java `PatriciaTrie<V>`; OCaml `ptmap` |
| **Fragment-keyed trie** | `Trie<K, V>` | `K` is the key-fragment type; actual key is `[K]` | Rust `SequenceTrie<K, V>`; Rust `radix_trie::Trie<K, V>` |
| **Generic trie** | `Trie<K, V>` via type class | `K` determines trie structure via type-level derivation | Haskell `generic-trie`; Haskell `MemoTrie` |

**Observation**: The fixed-key pattern is most common in production implementations, because fixing the key type allows aggressive optimization (bit manipulation, byte-level operations). The fragment-keyed pattern is most honest about the trie's nature — the key is explicitly a *sequence* of `K`s. The generic pattern is most principled type-theoretically but requires advanced type system features (type families, associated types, Generic deriving).

**The fundamental type-theoretic signature is**:

```
Trie : (K : Type) → (V : Type) → Type
where the actual key type is [K] (sequences of K)
```

This is distinct from both `Map K V` (where the key is `K` itself) and `Tree K V` (where `K` labels nodes or edges, not sequences).

### 4.2 Answering RQ2: Trie as Tree Variant vs Standalone

| Library | Classified As | Reasoning |
|---------|--------------|-----------|
| Haskell `Data.Map` | Map (tree impl) | Tree is implementation detail |
| Haskell `Data.IntMap` | Map (trie impl) | Trie is implementation detail |
| Haskell `Data.Trie` | Map with prefix ops | Map interface + trie-specific structural operations |
| Haskell `Data.HashMap` | Map (HAMT impl) | Trie is implementation detail |
| Haskell `Data.Tree` | Tree | Structural tree, no map semantics |
| Haskell `generic-trie` | Map (trie impl) | Map interface, trie structure derived from key type |
| Rust `BTreeMap` | Map (tree impl) | Tree is implementation detail |
| Rust `radix_trie` | **Trie** (own category) | Exposes trie-specific structural operations |
| Rust `sequence_trie` | **Trie** (own category) | Exposes trie-specific structural operations |
| OCaml `Map` | Map (AVL impl) | Tree is implementation detail |
| OCaml `patricia-tree` | Map (trie impl) | Map interface with Patricia-specific merge optimizations |
| C++ `std::map` | Map (RB-tree impl) | Tree is implementation detail |
| C++ `Boost.PropertyTree` | **Tree** (keyed tree) | Explicitly a tree with keyed edges |
| C++ HAT-trie | Map with prefix ops | Map interface + prefix search |
| Java `TreeMap` | Map (RB-tree impl) | Tree is implementation detail |
| Java `PatriciaTrie` | **Map + Trie** (dual) | Implements both `SortedMap` and `Trie` interfaces |
| Scala `TrieMap` | Map (Ctrie impl) | Map in type hierarchy, "Trie" in name only |
| Scala `HashMap` | Map (HAMT impl) | Trie is implementation detail |

**Synthesis**:

1. **No mainstream library classifies a trie as a tree variant.** Tries are universally classified as either maps (majority) or as their own category (minority). The only "tree" in this survey is `Boost.PropertyTree`, which is a keyed tree, not a trie.

2. **The split is between "trie-as-map" and "trie-as-its-own-thing"**:
   - **Trie-as-map** (majority): `IntMap`, `HashMap`, `Trie`, `PatriciaTrie`, `TrieMap`, OCaml Patricia trees. These provide map interfaces; the trie is an implementation strategy.
   - **Trie-as-standalone** (minority): Rust `radix_trie`, Rust `sequence_trie`. These expose trie-specific structural operations (subtrie extraction, prefix iteration, ancestor lookup) that map interfaces cannot express.

3. **Java's `PatriciaTrie` is the most honest design**: it simultaneously satisfies `SortedMap` (it is a map) and `Trie` (it has prefix-structural operations). This dual classification acknowledges the trie's genuinely dual nature.

### 4.3 Answering RQ3: Trie/Map/Tree Relationship in Type Theory

The academic literature provides a definitive answer:

**A trie is a map whose implementation is derived from the structure of its key type.**

More precisely, following Hinze (2000):

- A **Map K V** is any structure satisfying the finite map interface (insert, lookup, delete) with key type `K` and value type `V`.
- A **trie for type K** is a specific *implementation* of `Map [K] V` that exploits the recursive structure of `[K]` to decompose the map into nested sub-maps:

  ```
  Trie K V ≅ (Maybe V, Map K (Trie K V))
  ```

  That is: a node optionally holds a value (for the empty-key case), plus a map from single key-fragments to sub-tries.

- A **tree** is a hierarchical structure with parent/child relationships. Trees may or may not carry key-value semantics.

The relationships are:

```
                  Data Structure
                  /           \
                Map             Tree
              /    \          /      \
         Hash Map   Sorted  Rose    Keyed
            |       Map     Tree    Tree
           HAMT      |       |       |
            |      BST/AVL  Data.   Boost.
            |       RB      Tree    PropertyTree
            |
           Trie  (implementation strategy for Map)
          /    \
    IntMap    ByteString Trie
    HashMap   PatriciaTrie
    TrieMap   generic-trie
```

**The crucial insight**: A trie is not a *subtype* of either tree or map. It is a *map* by interface and a *tree* by structure. When the trie-specific structural operations (prefix search, subtrie extraction) are exposed, the trie transcends the map interface and becomes something that is genuinely both.

**Connelly & Morris's functor theorem** makes this precise: `Trie` is a functor (in the category-theoretic sense) from value types to itself, and the lookup operation is a natural isomorphism between the function type `K → Maybe V` and the data type `Trie K V`. Neither "map" nor "tree" fully captures this: it is a representational isomorphism between functions and data.

### 4.4 Answering RQ4: Keyed Tree Representations

Keyed trees — trees where edges or child positions carry labels/keys — are surprisingly rare in typed ecosystems:

| Structure | Type Signature | Children | Keyed? |
|-----------|---------------|----------|--------|
| Haskell `Data.Tree` | `Tree a` | `[Tree a]` | No — positional |
| swift-tree-primitives `Tree.Unbounded` | `Tree.Unbounded<Element>` | `Array<Index>` (arena) | No — positional |
| Boost.PropertyTree | `basic_ptree<Key, Data>` | `list<pair<Key, ptree>>` | **Yes** — each child has a key |
| JSON/XML DOM models | Various | Named children or ordered mixed | **Yes** — edge labels from spec |
| petgraph | `Graph<N, E>` | Edge weight `E` | Sort of — edges have weights, but no tree constraint |

**Observation**: The keyed-tree pattern is used almost exclusively for configuration/document representation (Boost.PropertyTree for JSON/XML/INI). General-purpose typed tree libraries universally use *positional* children (lists, arrays, fixed arity). The trie is the closest structure to a keyed tree, but with the critical distinction that trie keys are *sequences* (paths through the tree), not single edge labels.

**A keyed tree differs from a trie as follows**:

| Property | Keyed Tree | Trie |
|----------|-----------|------|
| Key semantics | Edge label (single level) | Path (multi-level sequence) |
| Lookup | Navigate one level by key | Navigate full path by key sequence |
| Children | Labeled by key at each node | Labeled by key-fragment at each node |
| Value storage | At every node | Optionally at every node |
| Structural identity | Tree with labeled edges | Map with exploitable key structure |

A keyed tree `Tree<K, V>` where each node has value `V` and children keyed by `K` is:

```
KeyedTree K V = (V, Map K (KeyedTree K V))
```

Compare with a trie:

```
Trie K V = (Maybe V, Map K (Trie K V))
```

The only difference is `V` vs `Maybe V` at each node — whether every node must hold a value, or only some nodes do. A keyed tree *requires* a value at every node; a trie allows nodes to exist purely as branching points without values.

---

## Part V: Child Representation Taxonomy

A critical implementation dimension is how each node maps key-fragments to children:

| Representation | Space | Lookup | Iteration | Used By |
|---------------|-------|--------|-----------|---------|
| **Fixed-size array** (dense) | O(Σ) per node, Σ = alphabet size | O(1) | O(Σ) | Classic textbook tries, Cedar (double-array) |
| **Hash map** (sparse) | O(k) per node, k = actual children | O(1) amortized | O(k) | Rust `sequence_trie`, HAT-trie buckets |
| **Sorted array** (sparse) | O(k) per node | O(log k) | O(k) ordered | B-tree children |
| **Linked list** (sparse) | O(k) per node | O(k) | O(k) | Rose tree children, Boost.PropertyTree |
| **Bitmap + compact array** (sparse) | O(k) + 32 bits per node | O(popcount) ≈ O(1) | O(k) | HAMT (Bagwell), Ctrie, Haskell HashMap |
| **Binary trie** (implicit) | O(1) per branch | O(1) | O(2) | Patricia trees (IntMap, PatriciaTrie) |
| **Ternary search tree** | O(1) per branch | O(log Σ) amortized | O(k) | Bentley-Sedgewick TST, Isabelle Trie_Map |

The HAMT bitmap representation has emerged as the dominant choice for general-purpose tries in modern functional/immutable collections (Clojure, Scala, Haskell `unordered-containers`), because it combines:
- Sparse storage (only populated children allocated)
- O(1) child lookup via `popcount(bitmap & (mask - 1))`
- Cache-friendly compact arrays
- Efficient persistent updates via path copying (only log₃₂(n) nodes copied)

---

## Part VI: Synthesis and Implications for Swift

### 6.1 The Classification Question

If swift-primitives were to add trie support, the literature unanimously suggests:

1. **A trie is a Map, not a Tree.** Every mainstream implementation classifies tries as maps. The tree structure is internal. This aligns with the existing swift-tree-primitives design, which explicitly states: "These are structural trees — they model parent/child relationships, not ordered search structures."

2. **Trie-specific operations (prefix search, subtrie extraction) should be exposed.** The Java `Trie` interface and Rust `radix_trie`/`sequence_trie` show that hiding all trie structure behind a pure map interface loses valuable capabilities.

3. **The canonical type signature is `Trie<K, V>` where the actual key is `[K]`** (a sequence of key fragments). This is more honest than `Trie<V>` with a fixed key type, and more practical than the fully generic Hinze derivation.

### 6.2 The Keyed-Tree Question

A keyed tree (`Tree<K, V>` with labeled edges) is a distinct concept from both tries and positional trees:

- `Tree.N<Element>` / `Tree.Unbounded<Element>` — positional children, no keys
- `Trie<K, V>` — sequence-keyed map, trie structure
- `Tree.Keyed<K, V>` — tree with labeled edges, every node has value

The keyed tree has very narrow real-world usage (configuration trees, DOM), and Boost.PropertyTree is effectively the only mainstream implementation. The trie has much broader applicability (string maps, routing tables, autocompletion, IP lookup, symbol tables).

### 6.3 Open Questions

1. **Module placement**: Should a trie primitive live in `swift-tree-primitives` (structural affinity) or a new `swift-trie-primitives` or `swift-map-primitives` (semantic affinity)? The literature strongly favors the latter.

2. **Child representation**: For a general-purpose trie in Swift, the HAMT bitmap approach is likely optimal for persistent (CoW) tries. For mutable string tries, a dense-array or hybrid (HAT-trie) approach may be preferable.

3. **Interaction with `~Copyable`**: No existing trie implementation supports noncopyable elements. swift-primitives' commitment to `~Copyable` would be a novel contribution.

4. **Prefix operations**: Any trie API should expose `prefixMap`, `longestPrefix`, and subtrie extraction — the operations that distinguish a trie from a plain map.

---

## Appendix A: Reference Bibliography

### Seminal Works

1. Fredkin, E. (1960). "Trie Memory." *Communications of the ACM*, 3(9), 490–499. [ACM DL](https://dl.acm.org/doi/10.1145/367390.367400)

2. Morrison, D.R. (1968). "PATRICIA — Practical Algorithm to Retrieve Information Coded in Alphanumeric." *Journal of the ACM*, 15(4), 514–534.

3. Connelly, R.H. & Morris, F.L. (1995). "A Generalization of the Trie Data Structure." *Mathematical Structures in Computer Science*, 5(3), 381–418. [Cambridge Core](https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/generalization-of-the-trie-data-structure/A766B214D44B9EF74C12F0CEF01C7409)

4. Okasaki, C. & Gill, A. (1998). "Fast Mergeable Integer Maps." *Workshop on ML*. [Paper](https://ku-fpg.github.io/papers/Okasaki-98-IntMap/)

5. Okasaki, C. (1998). *Purely Functional Data Structures*. Cambridge University Press.

6. Hinze, R. (2000). "Generalizing Generalized Tries." *Journal of Functional Programming*, 10(4), 327–351. [Cambridge Core](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/generalizing-generalized-tries/03C839ABDC2CE3326B73CDDD35DD568E)

7. Bagwell, P. (2001). "Ideal Hash Trees." EPFL Technical Report. [PDF](https://lampwww.epfl.ch/papers/idealhashtrees.pdf)

8. Prokopec, A., Bronson, N.G., Bagwell, P. & Odersky, M. (2012). "Concurrent Tries with Efficient Non-Blocking Snapshots." *PPoPP '12 / ACM SIGPLAN Notices*, 47(8), 151–160. [ACM DL](https://dl.acm.org/doi/10.1145/2370036.2145836)

### Implementation References

9. bytestring-trie (Haskell). [Hackage](https://hackage.haskell.org/package/bytestring-trie)

10. generic-trie (Haskell). [Hackage](https://hackage.haskell.org/package/generic-trie)

11. unordered-containers / Data.HashMap (Haskell). [Hackage](https://hackage.haskell.org/package/unordered-containers)

12. containers / Data.IntMap, Data.Map, Data.Tree (Haskell). [Hackage](https://hackage.haskell.org/package/containers)

13. MemoTrie (Haskell). [Hackage](https://hackage.haskell.org/package/MemoTrie-0.6.11/docs/Data-MemoTrie.html)

14. radix_trie (Rust). [crates.io](https://crates.io/crates/radix_trie); [docs.rs](https://docs.rs/radix_trie/latest/radix_trie/)

15. sequence_trie (Rust). [docs.rs](https://docs.rs/sequence_trie/latest/sequence_trie/)

16. BTreeMap (Rust). [std docs](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html)

17. patricia-tree (OCaml). [GitHub](https://github.com/codex-semantics-library/patricia-tree); [OCaml package](https://ocaml.org/p/patricia-tree/0.11.0/doc/index.html)

18. PatriciaTrie (Java, Apache Commons). [Javadoc](https://commons.apache.org/proper/commons-collections/apidocs/org/apache/commons/collections4/trie/PatriciaTrie.html)

19. TrieMap (Scala). [API docs](https://www.scala-lang.org/api/current/scala/collection/concurrent/TrieMap.html)

20. Boost.PropertyTree (C++). [Boost docs](https://www.boost.org/libs/property_tree)

21. HAT-trie (C++). [GitHub](https://github.com/Tessil/hat-trie)

22. Trie_Map theory (Isabelle/HOL). [Theory](https://www.cl.cam.ac.uk/research/hvg/Isabelle/dist/library/HOL/HOL-Data_Structures/Trie_Map.html)

### Additional References

23. Elliott, C. (2009). "Elegant Memoization with Functional Memo Tries." [Blog](http://conal.net/blog/posts/elegant-memoization-with-functional-memo-tries)

24. Askitis, N. & Sinha, R. (2007). "HAT-trie: A Cache-conscious Trie-based Data Structure for Strings." *Australasian Computer Science Conference*.

25. Steindorfer, M.J. & Vinju, J.J. (2015). "Optimizing Hash-Array Mapped Tries for Fast and Lean Immutable JVM Collections." *OOPSLA '15*.
