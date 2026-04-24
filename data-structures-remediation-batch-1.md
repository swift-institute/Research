# Remediation Plans: Batch 1 (HIGH)

Generated 2026-04-03.

## Prerequisite: Missing Variant Products

Several replacements require variant modules that exist as targets but are NOT
published as products. These must be promoted to products before consumer
packages can depend on them.

| Package | Target (exists) | Needs product? | Needed by |
|---------|----------------|----------------|-----------|
| swift-sequence-primitives | Sequence Primitives Core | **YES** | buffer, set, graph, bit-vector |
| swift-affine-primitives | Affine Primitives Core | **YES** | bit-vector |
| swift-queue-primitives | Queue Primitives Core | **YES** | graph |

Until these products are published, the umbrella imports for `Sequence_Primitives`,
`Affine_Primitives`, and `Queue_Primitives` cannot be narrowed in those consumers.
The tables below document the intended replacement assuming the products are
published.

---

## swift-bit-vector-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations):
- `Bit_Primitives` (canonical: bit)
- `Bit_Pack_Primitives` (canonical: bit-pack)
- `Index_Primitives` (canonical: index)

#### Source file violations

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+growth.swift | `import Affine_Primitives` | `.one`, `.zero`, `.subtract.saturating()` on `Bit.Index.Count` (Tagged Cardinal affine arithmetic) | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+mutating.swift | `import Affine_Primitives` | `.one`, `.zero` on `Index<UInt>` (affine arithmetic) | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded.swift | `import Affine_Primitives` | `.zero`, `.one`, `.subtract.saturating()` on `Bit.Index.Count` | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+conversions.swift | `import Affine_Primitives` | (transitively provides affine arithmetic on Tagged types) | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+growth.swift | `import Affine_Primitives` | `.one`, `.zero`, `.subtract.saturating()` on `Bit.Index.Count` | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+mutating.swift | `import Affine_Primitives` | `.one`, `.zero` on `Index<UInt>` (affine arithmetic) | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic.swift | `import Affine_Primitives` | `.zero`, `.one`, `.subtract.saturating()` on `Bit.Index.Count` | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+growth.swift | `import Affine_Primitives` | `.one`, `.zero`, `.subtract.saturating()` on `Bit.Index.Count` | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+mutating.swift | `import Affine_Primitives` | `.one`, `.zero` on `Index<UInt>` (affine arithmetic) | `import Affine_Primitives_Core` * |
| Sources/Bit Vector Inline Primitives/Bit.Vector.Inline.swift | `import Affine_Primitives` | `.zero`, `.one`, `.subtract.saturating()` on `Bit.Index.Count` | `import Affine_Primitives_Core` * |

\* Requires promoting `Affine Primitives Core` to a published product.

#### Package.swift violations

| Current product dep (line) | Replacement | Target affected | Blocked? |
|---------------------------|-------------|-----------------|----------|
| "Sequence Primitives" (L62) | "Sequence Primitives Core" | Bit Vector Primitives Core | **YES** -- Core not a product |

**Note**: `Sequence_Primitives` is a dependency of "Bit Vector Primitives Core" target.
The Core sources use `Sequence.Protocol`, `Sequence.Iterator.Protocol` (from
Sequence Primitives Core). The exports.swift also re-exports the umbrella. The
re-export in exports.swift should be narrowed to `Sequence_Primitives_Core` once
it becomes a product.

### Summary

- **9** source file violations (all `Affine_Primitives` -> `Affine_Primitives_Core`)
- **1** Package.swift violation (`Sequence_Primitives` -> `Sequence_Primitives_Core`)
- **All blocked** on prerequisite product promotions

---

## swift-buffer-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations):
- `Link_Primitives` (canonical: link)
- `Cyclic_Index_Primitives` (canonical: cyclic-index)
- `Finite_Primitives` (canonical: finite)
- `Index_Primitives` (canonical: index)
- `Vector_Primitives` (canonical: vector)

#### Source file violations

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Sources/Buffer Ring Primitives/Storage.Initialization.swift | `import Storage_Primitives` | `Storage.Initialization` (enum, tracks slot ranges) | `import Storage_Primitives_Core` |

#### Package.swift violations

| Current product dep (line) | Replacement | Target affected | Blocked? |
|---------------------------|-------------|-----------------|----------|
| "Storage Primitives" (L95) | "Storage Primitives Core" | Buffer Primitives Core | No |
| "Memory Primitives" (L97) | "Memory Primitives Core" | Buffer Primitives Core | No |
| "Bit Vector Primitives" (L98) | "Bit Vector Primitives Core" + "Bit Vector Bounded Primitives" + "Bit Vector Static Primitives" | Buffer Primitives Core | No |
| "Sequence Primitives" (L128) | "Sequence Primitives Core" | Buffer Ring Primitives | **YES** -- Core not a product |
| "Sequence Primitives" (L137) | "Sequence Primitives Core" | Buffer Ring Inline Primitives | **YES** |
| "Sequence Primitives" (L148) | "Sequence Primitives Core" | Buffer Linear Primitives | **YES** |
| "Sequence Primitives" (L159) | "Sequence Primitives Core" | Buffer Linear Inline Primitives | **YES** |
| "Sequence Primitives" (L170) | "Sequence Primitives Core" | Buffer Linear Small Primitives | **YES** |
| "Sequence Primitives" (L181) | "Sequence Primitives Core" | Buffer Slab Primitives | **YES** |
| "Sequence Primitives" (L190) | "Sequence Primitives Core" | Buffer Slab Inline Primitives | **YES** |
| "Sequence Primitives" (L200) | "Sequence Primitives Core" | Buffer Linked Primitives | **YES** |
| "Sequence Primitives" (L209) | "Sequence Primitives Core" | Buffer Linked Inline Primitives | **YES** |
| "Sequence Primitives" (L228) | "Sequence Primitives Core" | Buffer Arena Primitives | **YES** |
| "Sequence Primitives" (L237) | "Sequence Primitives Core" | Buffer Arena Inline Primitives | **YES** |

**Re-export note**: Buffer Primitives Core `exports.swift` currently re-exports:
- `@_exported public import Storage_Primitives` -> change to `Storage_Primitives_Core`
- `@_exported public import Bit_Vector_Primitives` -> change to individual variants or keep umbrella if consumers need all variants transitively

**Bit Vector breakdown** (types used by buffer targets):
- `Bit.Vector` (Core) -- used by Buffer Slab Primitives Core (`Bit.Vector.Bounded` bitmap headers)
- `Bit.Vector.Bounded` (Bounded variant) -- used by Buffer Slab Primitives Core
- `Bit.Vector.Static<wordCount>` (Static variant) -- used by Buffer Slab Primitives Core
- `Bit.Vector.Ones.Bounded`, `Bit.Vector.Ones.Bounded.Iterator` -- used by Buffer Slab Primitives
- Replacement: `"Bit Vector Primitives Core"` + `"Bit Vector Bounded Primitives"` + `"Bit Vector Static Primitives"`

**Sequence types used** (all from Core): `Sequence.Protocol`, `Sequence.Iterator.Protocol`,
`Sequence.Borrowing.Protocol`, `Sequence.Drain.Protocol`, `Sequence.Drain`,
`Sequence.Consume.Protocol`, `Sequence.Consume.View`, `Sequence.Clearable`.

### Summary

- **1** source file violation (`Storage_Primitives` -> `Storage_Primitives_Core`)
- **14** Package.swift violations (3 unblocked, 11 blocked on Sequence Primitives Core product)
- **3** unblocked: Storage, Memory, Bit Vector deps on Buffer Primitives Core target

---

## swift-graph-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations):
- `Tagged_Primitives` (canonical: identity)
- `Index_Primitives` (canonical: index)
- `Set_Primitives` (canonical: set)

#### Source file violations

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Sources/Graph Topological Primitives/Graph.Traversal.Topological.swift | `import Bit_Vector_Primitives` | `Bit.Vector` (core type, capacity-init + subscript) | `import Bit_Vector_Primitives_Core` |
| Sources/Graph DFS Primitives/Graph.Traversal.First.Depth.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |
| Sources/Graph DFS Primitives/Graph.Traversal.First.Depth.swift | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol` | `internal import Sequence_Primitives_Core` * |
| Sources/Graph BFS Primitives/Graph.Traversal.First.Breadth.swift | `public import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `public import Bit_Vector_Primitives_Core` |
| Sources/Graph BFS Primitives/Graph.Traversal.First.Breadth.swift | `internal import Sequence_Primitives` | `Sequence.Iterator.Protocol` | `internal import Sequence_Primitives_Core` * |
| Sources/Graph Reachable Primitives/Graph.Sequential.Analyze.Reachable.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |
| Sources/Graph Dead Primitives/Graph.Sequential.Analyze.Dead.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |
| Sources/Graph SCC Primitives/Graph.Sequential.Analyze.SCC.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |
| Sources/Graph Transitive Closure Primitives/Graph.Sequential.Analyze.TransitiveClosure.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |
| Sources/Graph Path Exists Primitives/Graph.Sequential.Path.Exists.swift | `public import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `public import Bit_Vector_Primitives_Core` |
| Sources/Graph Shortest Path Primitives/Graph.Sequential.Path.Shortest.swift | `public import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `public import Bit_Vector_Primitives_Core` |
| Sources/Graph Weighted Path Primitives/Graph.Sequential.Path.Weighted.swift | `public import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `public import Bit_Vector_Primitives_Core` |
| Sources/Graph Weighted Path Primitives/Graph.Sequential.Path.Weighted.swift | `public import Heap_Primitives` | `Heap` (core struct) | `public import Heap_Primitives_Core` |
| Sources/Graph Backward Reachable Primitives/Graph.Sequential.Reverse.Reachable.swift | `internal import Bit_Vector_Primitives` | `Bit.Vector` (core type) | `internal import Bit_Vector_Primitives_Core` |

\* Requires promoting `Sequence Primitives Core` to a published product.

#### Package.swift violations

| Current product dep (line) | Replacement | Target affected | Blocked? |
|---------------------------|-------------|-----------------|----------|
| "Array Primitives" (L108) | "Array Primitives Core" + "Array Dynamic Primitives" | Graph Primitives Core | No |
| "Bit Vector Primitives" (L119) | "Bit Vector Primitives Core" | Graph DFS Primitives | No |
| "Sequence Primitives" (L120) | "Sequence Primitives Core" | Graph DFS Primitives | **YES** |
| "Queue Primitives" (L127) | "Queue Primitives Core" | Graph BFS Primitives | **YES** -- Core not a product |
| "Bit Vector Primitives" (L128) | "Bit Vector Primitives Core" | Graph BFS Primitives | No |
| "Sequence Primitives" (L129) | "Sequence Primitives Core" | Graph BFS Primitives | **YES** |
| "Bit Vector Primitives" (L137) | "Bit Vector Primitives Core" | Graph Topological Primitives | No |
| "Bit Vector Primitives" (L148) | "Bit Vector Primitives Core" | Graph Reachable Primitives | No |
| "Bit Vector Primitives" (L158) | "Bit Vector Primitives Core" | Graph Dead Primitives | No |
| "Bit Vector Primitives" (L167) | "Bit Vector Primitives Core" | Graph SCC Primitives | No |
| "Bit Vector Primitives" (L182) | "Bit Vector Primitives Core" | Graph Transitive Closure Primitives | No |
| "Queue Primitives" (L192) | "Queue Primitives Core" | Graph Path Exists Primitives | **YES** |
| "Bit Vector Primitives" (L193) | "Bit Vector Primitives Core" | Graph Path Exists Primitives | No |
| "Queue Primitives" (L200) | "Queue Primitives Core" | Graph Shortest Path Primitives | **YES** |
| "Bit Vector Primitives" (L201) | "Bit Vector Primitives Core" | Graph Shortest Path Primitives | No |
| "Heap Primitives" (L208) | "Heap Primitives Core" | Graph Weighted Path Primitives | No |
| "Bit Vector Primitives" (L209) | "Bit Vector Primitives Core" | Graph Weighted Path Primitives | No |
| "Bit Vector Primitives" (L243) | "Bit Vector Primitives Core" | Graph Backward Reachable Primitives | No |

**Array breakdown** (Graph Primitives Core):
- `Array` (Core) -- used for `Graph.Sequential.Builder.storage`
- `Array.Indexed<Tag>` (Dynamic) -- used for `Graph.Sequential.storage`, traversal iterators
- `Array.Fixed.Indexed<Tag>` (Fixed) -- used by SCC, Transitive Closure, Subgraph, etc.

The Core target re-exports `Array_Primitives` in its exports.swift. The Array dep should
be split: Core target needs `"Array Primitives Core"` + `"Array Dynamic Primitives"`.
The Fixed variant is used by downstream targets (SCC, Transitive Closure, etc.) which
inherit Core's dependency. Those targets should add `"Array Fixed Primitives"` directly
if they use `Array.Fixed.Indexed`, or Core should broaden its dep.

### Summary

- **14** source file violations (10 Bit_Vector, 2 Sequence, 1 Heap, 1 Array via re-export)
- **18** Package.swift violations (13 unblocked, 5 blocked on Sequence/Queue Core products)
- **13** unblocked: all Bit Vector, Heap, Array replacements

---

## swift-set-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations):
- `Bit_Primitives` (canonical: bit)
- `Index_Primitives` (canonical: index)
- `Hash_Table_Primitives` (canonical: hash-table)
- `Ordinal_Primitives` (canonical: ordinal)
- `Cardinal_Primitives` (canonical: cardinal)
- `Finite_Primitives` (canonical: finite)

#### Source file violations

The violations file lists source file imports of `Index_Primitives`, `Cardinal_Primitives`,
`Ordinal_Primitives`, `Sequence_Primitives`, `Hash_Table_Primitives`, `Finite_Primitives`
in Set Ordered Primitives. After filtering canonical umbrellas, only `Sequence_Primitives`
remains as a true source-file violation.

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Sources/Set Ordered Primitives/Set.Ordered+Sequence.Consume.swift | `import Sequence_Primitives` | `Sequence.Consume.Protocol`, `Sequence.Consume.View` | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered+Sequence.Drain.swift | `import Sequence_Primitives` | `Sequence.Drain.Protocol`, `Sequence.Drain` (tag) | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift | `import Sequence_Primitives` | `Sequence.Consume.Protocol`, `Sequence.Consume.View` | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Drain.swift | `import Sequence_Primitives` | `Sequence.Drain.Protocol`, `Sequence.Drain` (tag) | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Small+Sequence.Consume.swift | `import Sequence_Primitives` | `Sequence.Consume.Protocol`, `Sequence.Consume.View` | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Small+Sequence.Drain.swift | `import Sequence_Primitives` | `Sequence.Drain.Protocol` | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Static+Sequence.Consume.swift | `import Sequence_Primitives` | `Sequence.Consume.Protocol`, `Sequence.Consume.View` | `import Sequence_Primitives_Core` * |
| Sources/Set Ordered Primitives/Set.Ordered.Static+Sequence.Drain.swift | `import Sequence_Primitives` | `Sequence.Drain.Protocol` | `import Sequence_Primitives_Core` * |

\* Requires promoting `Sequence Primitives Core` to a published product.

#### Package.swift violations

| Current product dep (line) | Replacement | Target affected | Blocked? |
|---------------------------|-------------|-----------------|----------|
| "Storage Primitives" (L51) | "Storage Primitives Core" | Set Primitives Core | No |
| "Buffer Primitives" (L52) | "Buffer Primitives Core" + "Buffer Linear Primitives" + "Buffer Linear Inline Primitives" + "Buffer Linear Small Primitives" | Set Primitives Core | No |
| "Memory Primitives" (L53) | "Memory Primitives Core" | Set Primitives Core | No |
| "Sequence Primitives" (L64) | "Sequence Primitives Core" | Set Ordered Primitives | **YES** -- Core not a product |

**Buffer breakdown** (Set Primitives Core):
- `Buffer<Element>.Linear` -- from Buffer Linear Primitives (product, includes Core)
- `Buffer<Element>.Linear.Bounded` -- from Buffer Linear Primitives (product)
- `Buffer<Element>.Linear.Inline<capacity>` -- from Buffer Linear Inline Primitives (product)
- `Buffer<Element>.Linear.Small<inlineCapacity>` -- from Buffer Linear Small Primitives (product)

**Re-export note**: Set Primitives Core `exports.swift` re-exports three banned umbrellas:
- `@_exported public import Storage_Primitives` -> `@_exported public import Storage_Primitives_Core`
- `@_exported public import Buffer_Primitives` -> replace with specific variant re-exports:
  - `@_exported public import Buffer_Primitives_Core`
  - `@_exported public import Buffer_Linear_Primitives`
  - `@_exported public import Buffer_Linear_Inline_Primitives`
  - `@_exported public import Buffer_Linear_Small_Primitives`
- `@_exported public import Memory_Primitives` -> `@_exported public import Memory_Primitives_Core`

**Note**: The Storage and Memory umbrella deps on Set Primitives Core exist primarily for
transitive re-export. Set code does not directly reference `Storage.` or `Memory.` types
in executable code -- only in documentation comments.

### Summary

- **8** source file violations (all `Sequence_Primitives` -> `Sequence_Primitives_Core`)
- **4** Package.swift violations (3 unblocked, 1 blocked on Sequence Primitives Core product)
- **3** unblocked: Storage, Buffer, Memory deps on Set Primitives Core target

---

## Cross-Cutting Statistics

| Package | Source violations | Pkg.swift violations | Unblocked | Blocked |
|---------|-----------------|---------------------|-----------|---------|
| swift-bit-vector-primitives | 9 | 1 | 0 | 10 |
| swift-buffer-primitives | 1 | 14 | 4 | 11 |
| swift-graph-primitives | 14 | 18 | 27 | 5 |
| swift-set-primitives | 8 | 4 | 3 | 9 |
| **Total** | **32** | **37** | **34** | **35** |

### Blocking dependency chain

```
Promote Sequence Primitives Core -> unblocks 23 violations (buffer x11, set x9, graph x2, bit-vector x1)
Promote Affine Primitives Core   -> unblocks  9 violations (bit-vector x9)
Promote Queue Primitives Core    -> unblocks  3 violations (graph x3)
                                   --------
                                   Total: 35 blocked -> 0
```
