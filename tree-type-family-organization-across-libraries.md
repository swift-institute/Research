# Tree Type Family Organization Across Libraries

<!--
---
version: 1.0.0
date: 2026-03-01
scope: tree-primitives, trie, map, type-hierarchy
type: comparative-analysis
---
-->

## Executive Summary

**Core finding: Every major library treats the tree as an implementation detail of the map/set abstraction, not as the primary type identity. Tries are universally classified as maps that happen to use tree structure, not as trees that happen to support lookup.**

Across seven ecosystems and the academic literature, one pattern is unanimous: when a library has multiple tree variants (binary search tree, B-tree, red-black tree, trie, HAMT), they do **not** share a common `Tree` protocol or trait. Instead, the tree-backed types conform to the `Map`/`Set`/`Dictionary` abstraction appropriate to their ecosystem. The tree is the mechanism; the map is the identity.

The sole exception is GNU libstdc++ `__gnu_pbds`, which explicitly models `tree_tag` and `trie_tag` as siblings under `basic_branch_tag` -- but even there, the branching concept is subordinate to the `associative_tag` parent.

---

## 1. Haskell `containers`

### Type Organization

| Module | Implementation | Shared Typeclass with Data.Tree? |
|--------|---------------|----------------------------------|
| `Data.Map` | Size-balanced binary tree (AVL-like) | No |
| `Data.Set` | Size-balanced binary tree | No |
| `Data.IntMap` | Big-endian Patricia trie | No |
| `Data.IntSet` | Big-endian Patricia trie | No |
| `Data.Tree` | Rose tree (multi-way, lazy, possibly infinite) | N/A (it is Data.Tree) |
| `Data.Sequence` | Finger tree | No |

### Key Design Decisions

**No common Tree typeclass exists.** `Data.Map`, `Data.Set`, `Data.IntMap`, and `Data.Tree` are entirely independent types. They share Haskell's general typeclasses (`Foldable`, `Traversable`, `Functor` where applicable), but these are not tree-specific -- they apply equally to lists and arrays.

**Data.Tree is structurally a tree; Data.Map is semantically a map.** `Data.Tree` exposes tree structure (parent, children, forest). `Data.Map` exposes map operations (lookup, insert, union). The fact that `Data.Map` is internally a balanced binary tree is never surfaced in its API.

**Data.IntMap is a trie but presents as a map.** Its implementation is a big-endian Patricia trie (following Okasaki), but its API is deliberately parallel to `Data.Map`. The Haskell community explicitly chose not to create a common `Map` typeclass because: (a) typeclass dispatch overhead is significant for pure data structure operations, and (b) the types have different kinds (`Map k v` vs `IntMap v` -- the key type is fixed in IntMap).

**The bytestring-trie package** (`Data.Trie`) is documented as "an efficient finite map from bytestrings to values" -- the word "map" appears in its identity, not "tree."

### Verdict

Trees are implementation details. Maps and sets are the user-facing identity. No common `Tree` abstraction bridges them.

**Sources:**
- [containers package on Hackage](https://hackage.haskell.org/package/containers)
- [Data.Tree documentation](https://hackage-content.haskell.org/package/containers-0.8/docs/Data-Tree.html)
- [Data.IntMap documentation](https://hackage-content.haskell.org/package/containers-0.8/docs/Data-IntMap.html)
- [bytestring-trie package](https://hackage.haskell.org/package/bytestring-trie)
- [Picnic: put containers into a backpack (on lack of common Map typeclass)](https://kowainik.github.io/posts/2018-08-19-picnic-put-containers-into-a-backpack)
- [Patricia Tries in Haskell](https://jelv.is/projects/different-tries/)

---

## 2. Rust Collections

### Standard Library

| Type | Implementation | Shared Tree Trait? |
|------|---------------|-------------------|
| `BTreeMap<K, V>` | B-tree | No |
| `BTreeSet<K>` | B-tree (wrapper around BTreeMap) | No |
| `HashMap<K, V>` | Hash table (SwissTable) | No |
| `HashSet<K>` | Hash table (wrapper around HashMap) | No |

### Key Design Decisions

**No `Tree` trait exists in std.** `BTreeMap` and `BTreeSet` implement the standard collection traits (`IntoIterator`, `FromIterator`, `Extend`, `Index`) and require `Ord` on keys. The "B-tree" in the name describes the implementation strategy, not the type identity.

**BTreeSet wraps BTreeMap.** This is the map-first pattern: the set is defined in terms of the map (`BTreeSet<K>` is morally `BTreeMap<K, ()>`), not in terms of a shared tree abstraction.

### External Ecosystem

The `radix_trie` crate provides `Trie<K, V>` with a `TrieCommon` trait for shared functionality between tries and sub-tries. This trait provides iterators and prefix operations -- it is trie-specific, not tree-generic.

The `trie` crate provides `trie::map::Map` -- again, the type identity is "map," with the trie as mechanism.

**petgraph** treats trees as special cases of graphs (acyclic connected graphs). There is no separate tree abstraction; graph traits (`GraphBase`, `IntoNodeReferences`, `IntoEdgeReferences`) subsume tree use cases.

### Verdict

No common tree trait. The type identity follows the collection abstraction (Map, Set). External trie crates model themselves as maps or provide trie-specific traits, not tree-generic traits.

**Sources:**
- [BTreeMap documentation](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html)
- [BTreeSet documentation](https://doc.rust-lang.org/std/collections/struct.BTreeSet.html)
- [Rust Collections Case Study: BTreeMap](https://cglab.ca/~abeinges/blah/rust-btree-case/)
- [radix_trie crate: TrieCommon trait](https://docs.rs/radix_trie/latest/radix_trie/trait.TrieCommon.html)
- [petgraph crate](https://docs.rs/petgraph/latest/petgraph/)

---

## 3. Java Collections Framework

### Type Hierarchy

```
Iterable
└── Collection
    └── Set
        └── SortedSet
            └── NavigableSet
                └── TreeSet          (red-black tree)

Map
└── SortedMap
    └── NavigableMap
        └── TreeMap                  (red-black tree)
```

### Key Design Decisions

**TreeMap implements NavigableMap, not any Tree interface.** There is no `Tree` interface in `java.util`. The class hierarchy is: `TreeMap extends AbstractMap implements NavigableMap, Cloneable, Serializable`. The "Tree" in the name is a hint about implementation strategy, not a type relationship.

**TreeSet wraps TreeMap.** Just as in Rust, the set is defined in terms of the map. `TreeSet` internally delegates to a `TreeMap<E, Object>`.

**HashMap and TreeMap share the Map interface.** They are interchangeable at the `Map` level. The tree is invisible to consumers who program to the interface.

**No Tree interface exists.** Java has no `java.util.Tree` or `java.util.TreeNode` in the collections framework. The AWT/Swing `TreeModel` and `TreeNode` interfaces exist for UI trees but are completely unrelated to the collections hierarchy.

### Apache Commons Collections: Trie as SortedMap

Apache Commons Collections 4 includes a `Trie<K, V>` interface. Its superinterfaces are:

```
Trie<K, V> extends IterableSortedMap<K, V>
    extends SortedMap<K, V>
        extends Map<K, V>
```

`PatriciaTrie` implements `Trie` and therefore `SortedMap`. The trie is explicitly modeled as a specialized sorted map, not as a type of tree.

### Verdict

Maps that happen to use trees, never trees that happen to support lookup. The trie (in Apache Commons) extends `SortedMap`. There is no shared tree abstraction.

**Sources:**
- [TreeMap Java 8 Javadoc](https://docs.oracle.com/javase/8/docs/api/java/util/TreeMap.html)
- [A Guide to TreeMap in Java (Baeldung)](https://www.baeldung.com/java-treemap)
- [Java NavigableMap and TreeMap Tutorial](https://www.codejava.net/java-core/collections/java-navigablemap-and-treemap-tutorial-and-examples)
- [PatriciaTrie Apache Commons Collections 4.5.0](https://commons.apache.org/proper/commons-collections/apidocs/org/apache/commons/collections4/trie/PatriciaTrie.html)
- [Trie interface Apache Commons Collections 4.5.0](https://javadoc.io/static/org.apache.commons/commons-collections4/4.5.0/org/apache/commons/collections4/Trie.html)

---

## 4. C++ STL and GNU Policy-Based Data Structures

### Standard Library (STL)

| Type | Implementation | Concept Satisfied |
|------|---------------|------------------|
| `std::map` | Red-black tree (typically) | AssociativeContainer, ReversibleContainer |
| `std::set` | Red-black tree (typically) | AssociativeContainer, ReversibleContainer |
| `std::multimap` | Red-black tree | AssociativeContainer |
| `std::unordered_map` | Hash table | UnorderedAssociativeContainer |

**The tree is completely hidden.** The C++ standard does not mandate red-black trees -- it mandates O(log n) complexity guarantees. The `rb_tree` type is an internal implementation detail (`<bits/stl_tree.h>` says "This is an internal header file... Do not attempt to use it directly.").

There is no `Tree` concept in the C++ standard. The concept hierarchy is:
- `Container` -> `AssociativeContainer` (sorted, O(log n))
- `Container` -> `UnorderedAssociativeContainer` (hashed, O(1) average)

### GNU `__gnu_pbds` (Policy-Based Data Structures)

This is the **one library that explicitly models the tree/trie relationship**:

```cpp
struct container_tag { };
struct associative_tag : public container_tag { };
struct basic_branch_tag : public associative_tag { };
struct tree_tag : public basic_branch_tag { };    // sibling
struct trie_tag : public basic_branch_tag { };    // sibling
struct pat_trie_tag : public trie_tag { };

// Tree-specific tags:
struct rb_tree_tag : public tree_tag { };
struct splay_tree_tag : public tree_tag { };
struct ov_tree_tag : public tree_tag { };
```

Key observations:
- `tree_tag` and `trie_tag` are **siblings** under `basic_branch_tag`
- Both are subordinate to `associative_tag` -- they are associative containers first, branches second
- The `basic_branch` class provides `split()` and other operations common to both tree and trie containers
- Despite being siblings, tree and trie containers have different policy parameters: trees are parameterized by `Cmp_Fn` (comparator), tries by `E_Access_Traits` (element access traits)

This is the closest any library comes to a unified tree/trie abstraction, and even here the primary identity is "associative container."

### Verdict

In the standard library, the tree is a completely invisible implementation detail. In GNU PBDS, tree and trie are explicitly modeled as sibling branches under a common `basic_branch_tag`, but both are subordinate to `associative_tag`.

**Sources:**
- [C++ Containers Library (cppreference)](https://en.cppreference.com/w/cpp/container.html)
- [Inside STL: map, set, multimap, multiset (Raymond Chen)](https://devblogs.microsoft.com/oldnewthing/20230807-00/?p=108562)
- [STL's Red-Black Trees (Dr. Dobb's)](https://www.drdobbs.com/cpp/stls-red-black-trees/184410531)
- [GNU PBDS Design](https://gcc.gnu.org/onlinedocs/libstdc++/manual/policy_data_structures_design.html)
- [tag_and_trait.hpp source (GCC mirror)](https://github.com/gcc-mirror/gcc/blob/master/libstdc++-v3/include/ext/pb_ds/tag_and_trait.hpp)
- [Abseil B-tree containers](https://abseil.io/about/design/btree)

---

## 5. Scala Collections

### Type Hierarchy

```
Iterable
└── Map
    ├── SortedMap
    │   └── TreeMap         (red-black tree)
    ├── HashMap             (HAMT / CHAMP trie internally!)
    └── ...

concurrent.Map
└── TrieMap                 (concurrent trie map)
```

### Key Design Decisions

**HashMap is internally a HAMT trie but presents as a Map.** Scala 2.13's immutable `HashMap` is implemented as a Compressed Hash-Array Mapped Prefix-tree (CHAMP), an optimized variant of Phil Bagwell's HAMT. Despite being a trie internally, its type identity is `HashMap` and it conforms to `Map`, `MapOps`, `AbstractMap`.

**TreeMap extends SortedMap, not any Tree trait.** The "Tree" prefix indicates the implementation (red-black tree), not a type family membership. `TreeMap` and `HashMap` share `AbstractMap` as a common base -- the map abstraction unifies them, not a tree abstraction.

**TrieMap is in `scala.collection.concurrent`.** It extends `concurrent.Map`, not any trie-specific trait. The "Trie" in the name is implementation description.

**Both HashMap (HAMT trie) and TreeMap (red-black tree) conform to Map.** The collection hierarchy unifies them at the Map level regardless of their wildly different internal structures.

### Verdict

The map abstraction is the type identity. HashMap's trie implementation is invisible at the type level. TreeMap's tree implementation is invisible at the type level. No shared tree or trie abstraction exists.

**Sources:**
- [Scala immutable TreeMap 2.13](https://www.scala-lang.org/api/current/scala/collection/immutable/TreeMap.html)
- [Scala immutable HashMap 2.13](https://www.scala-lang.org/api/2.13.15/scala/collection/immutable/HashMap.html)
- [Scala concurrent TrieMap](https://www.scala-lang.org/api/current/scala/collection/concurrent/TrieMap.html)
- [CHAMP paper: Optimizing Hash-Array Mapped Tries](https://michael.steindorfer.name/publications/oopsla15.pdf)
- [HAMT on Wikipedia](https://en.wikipedia.org/wiki/Hash_array_mapped_trie)

---

## 6. Swift Standard Library and swift-collections

### Standard Library

| Type | Implementation | Protocol Conformances |
|------|---------------|----------------------|
| `Dictionary<K, V>` | Hash table | `Collection`, `Hashable` keys |
| `Set<E>` | Hash table | `Collection`, `SetAlgebra` |

No tree-backed collections exist in the standard library.

### swift-collections

| Module | Type | Implementation | Primary Conformance |
|--------|------|---------------|-------------------|
| `HashTreeCollections` | `TreeDictionary<K, V>` | CHAMP (compressed hash-array mapped prefix tree) | `Collection`, `Sequence` |
| `HashTreeCollections` | `TreeSet<K>` | CHAMP | `Collection`, `Sequence`, `SetAlgebra` |
| `OrderedCollections` | `OrderedDictionary<K, V>` | Hash table + array | `Sequence` |
| `OrderedCollections` | `OrderedSet<K>` | Hash table + array | `Collection`, `SetAlgebra` |

### Key Design Decisions

**No shared Dictionary protocol bridges Dictionary, TreeDictionary, and OrderedDictionary.** Each provides APIs parallel to `Dictionary` but there is no common `DictionaryProtocol` they all conform to. (Swift's standard library provides no such protocol either.)

**TreeDictionary is in `HashTreeCollections`, not in a `Tree` module.** The module name emphasizes "hash tree" -- the hashing strategy -- not tree-ness. TreeDictionary's identity is "a persistent dictionary with efficient structural sharing," not "a tree."

**TreeDictionary and TreeSet are CHAMP tries.** They are hash-array mapped prefix trees -- tries indexed by hash bits. Despite "Tree" in the name, the user-facing API is dictionary/set operations, not tree traversal.

**No protocol unifies tree-backed and hash-backed variants.** `Dictionary`, `TreeDictionary`, and `OrderedDictionary` exist as independent types. Consumers choose by construction, not by protocol.

### Verdict

Same pattern as all others: the tree/trie is an implementation detail. The dictionary/set abstraction is the type identity. No shared tree protocol exists.

**Sources:**
- [swift-collections README](https://github.com/apple/swift-collections/blob/main/README.md)
- [TreeDictionary source](https://github.com/apple/swift-collections/blob/main/Sources/HashTreeCollections/TreeDictionary/TreeDictionary.swift)
- [TreeDictionary+Collection source](https://github.com/apple/swift-collections/blob/main/Sources/HashTreeCollections/TreeDictionary/TreeDictionary+Collection.swift)
- [Swift Collections 1.1 release](https://github.com/apple/swift-collections/releases/tag/1.1.0)
- [Introducing Swift Collections](https://www.swift.org/blog/swift-collections/)
- [Discovering Swift Collections package](https://swiftwithmajid.com/2024/02/19/discovering-swift-collections-package/)

---

## 7. Clojure Persistent Collections

### Type Hierarchy

```
IPersistentMap
├── PersistentHashMap      (HAMT internally)
├── PersistentTreeMap      (red-black tree internally)
└── PersistentArrayMap     (small linear scan)
```

### Key Design Decisions

**PersistentHashMap is a HAMT but conforms to IPersistentMap.** Rich Hickey's modification of Phil Bagwell's HAMT provides the persistent hash map. Despite being a trie, it presents as `IPersistentMap`.

**PersistentTreeMap is a red-black tree but conforms to IPersistentMap.** The sorted variant uses a red-black tree internally. Same interface.

**Both extend APersistentMap.** The abstract base class provides the common map behavior. There is no `Tree` or `Trie` interface.

### Verdict

Identical pattern: map-first identity, tree/trie as implementation.

**Sources:**
- [PersistentHashMap source (Clojure)](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentHashMap.java)
- [PersistentTreeMap source (Clojure)](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentTreeMap.java)
- [Clojure Data Structures reference](https://clojure.org/reference/data_structures)

---

## 8. Academic Perspective

### Okasaki: Tries Are Generalized Finite Maps

In Chapter 10 of *Purely Functional Data Structures* (1998), Chris Okasaki presents tries under the heading of **structural abstraction**. His treatment is explicit:

- A trie is a **finite map** where the key is a composite type (e.g., a list of characters)
- The trie structure arises from decomposing the key type: if the key is a list, the map becomes a recursive nesting of maps
- He names his types `MapStr`, `MapBin`, `MapStrR` -- the prefix is `Map`, not `Tree`

Okasaki does not classify tries as trees. He classifies them as maps whose structure is induced by the key type.

### Hinze: Tries Are Type-Indexed Finite Maps

Ralf Hinze's "Generalizing Generalized Tries" (Journal of Functional Programming, 2000) makes the relationship precise:

- `Map<k> v` represents finite maps from `k` to `v`
- The type `Map<k>` is defined by induction on the structure of `k` (the key type)
- `Map<k>` is a unary functor
- For product keys: the map becomes nested maps
- For sum keys: the map becomes a product of maps
- For recursive keys (like lists or trees): the map becomes a recursive data type -- which happens to be a trie

The key insight: **a trie is what you get when you systematically derive a finite map from the structure of the key type.** The trie is not a tree that supports lookup; it is a map whose internal branching is determined by key decomposition.

### Wikipedia Classification

Wikipedia classifies a trie as "a type of k-ary search tree" and "an ordered tree data structure used to store a dynamic set or associative array." This dual classification reflects the structural reality: a trie IS a tree structurally, but its PURPOSE is to be an associative container.

**Sources:**
- [Okasaki's thesis (CMU-CS-96-177)](https://www.cs.cmu.edu/~rwh/students/okasaki.pdf)
- [Generalized Tries in OCaml (summary of Okasaki Ch. 10)](https://kunigami.wordpress.com/2017/12/15/generalized-tries-in-ocaml/)
- [Hinze: Generalizing Generalized Tries](https://www.cs.ox.ac.uk/ralf.hinze/publications/GGTries/index.html)
- [Hinze: Generalizing Generalized Tries (Cambridge)](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/generalizing-generalized-tries/03C839ABDC2CE3326B73CDDD35DD568E)

---

## 9. Synthesis: The Three Questions

### Question: Do tree variants share a common Tree protocol/trait?

**Answer: No, in any mainstream library.** Not in Haskell, Rust, Java, C++, Scala, Swift, or Clojure. The sole partial exception is GNU PBDS, where `tree_tag` and `trie_tag` are siblings under `basic_branch_tag` -- but this is a compile-time tag hierarchy for policy dispatch, not a runtime protocol.

### Question: Is a trie a tree variant, a map variant, or its own thing?

**Answer: (b) A trie is a map variant.**

The evidence is unanimous across all ecosystems:

| Ecosystem | Trie Type | Conforms To | Tree Protocol? |
|-----------|-----------|-------------|----------------|
| Haskell | `Data.IntMap` (Patricia trie) | Same API as `Data.Map` | No |
| Haskell | `Data.Trie` | "Efficient finite map" | No |
| Rust | `radix_trie::Trie` | Map-like API | No |
| Java | `PatriciaTrie` | `SortedMap<K, V>` | No |
| C++ PBDS | `trie<K, V>` | `associative_tag` | No (sibling of `tree_tag`) |
| Scala | `HashMap` (HAMT trie) | `Map[K, V]` | No |
| Scala | `TrieMap` | `concurrent.Map[K, V]` | No |
| Swift | `TreeDictionary` (CHAMP) | `Collection`, `Sequence` | No |
| Clojure | `PersistentHashMap` (HAMT) | `IPersistentMap` | No |
| Okasaki | `MapStr`, `MapBin` | Finite map abstraction | No |
| Hinze | `Map<k> v` | Finite map functor | No |

A trie is structurally a tree (it has nodes, edges, parent-child relationships). But its type identity in every library is "map" or "associative container." The tree structure is the implementation mechanism for key decomposition, not the user-facing abstraction.

### Question: When a library names something TreeMap or TreeDictionary, is "tree" the noun or the adjective?

**Answer: "Tree" is always the adjective.** These are:
- **Tree**Map = a Map implemented with a tree
- **Tree**Set = a Set implemented with a tree
- **Tree**Dictionary = a Dictionary implemented with a tree

Never:
- Tree**Map** = a tree that supports map operations

This is consistent across Java (`TreeMap implements NavigableMap`), Scala (`TreeMap extends SortedMap`), Swift (`TreeDictionary` conforms to `Collection`/`Sequence`), and Clojure (`PersistentTreeMap extends APersistentMap`).

---

## 10. Implications for swift-primitives

### Current swift-tree-primitives Design

The existing `swift-tree-primitives` package provides `Tree.N<Element, let n: Int>` -- a general-purpose arena-based n-ary tree with traversal iterators. This is a structural tree: its identity IS "tree," and it exposes tree operations (parent, children, insert at slot, traversal orders).

This is the correct design for a structural tree primitive. It is NOT a map. It does not provide key-value lookup. It is the kind of thing `Data.Tree` is in Haskell -- a tree whose purpose is to be a tree.

### Where Trie Would Live

If swift-primitives were to provide a trie, the precedent from every library studied says:

1. The trie should conform to map/dictionary protocols, not to a tree protocol
2. The trie should live alongside other map implementations (hash map, sorted map, trie map), not alongside tree implementations
3. The trie's tree structure should be an internal implementation detail
4. Naming should follow the pattern `Trie.Map<K, V>` or similar, where the map identity is primary

### Structural Tree vs. Map-Backing Tree

The research reveals two entirely separate use cases for trees:

| Use Case | Identity | Examples | Protocol |
|----------|----------|----------|----------|
| **Structural tree** | Tree IS the abstraction | DOM tree, file system tree, AST, scene graph | Tree traversal, parent/child |
| **Map-backing tree** | Tree is implementation detail | TreeMap, BTreeMap, HAMT, Patricia trie | Map/Dictionary/Set |

These should NOT share a common protocol. A DOM tree and a `TreeMap` have nothing useful in common at the API level, even though both are trees internally.

### The GNU PBDS Lesson

GNU PBDS's `basic_branch_tag` unifying tree and trie is the closest any library comes to bridging these concepts. But even there:
- The shared operations (`split`, `join`) are specialized branch operations, not general tree operations
- Tree and trie have different policy parameters (comparator vs. element-access traits)
- The primary identity remains `associative_tag`

The lesson: if you do want to capture the "branching associative container" concept, it belongs in the associative container hierarchy, not in the tree hierarchy.
