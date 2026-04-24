# Remediation Plans: Batch 4 (MEDIUM + LOW)

**Generated**: 2026-04-03
**Scope**: All packages with <=10 total violations (MEDIUM + LOW priority)
**Skipped**: Batches 1-3 cover the 11 HIGH packages (swift-set, swift-buffer, swift-graph, swift-bit-vector, swift-slab, swift-finite, swift-storage, swift-binary-parser, swift-parser-machine, swift-array, swift-async)

---

## Packages clean after filtering canonical umbrellas

These packages' violations involve ONLY canonical umbrellas and require no changes.

1. swift-abstract-syntax-tree-primitives (only imported Source Primitives -- source is canonical)
2. swift-affine-primitives (only imported Ordinal, Cardinal -- both canonical)
3. swift-algebra-cardinal-primitives (only imported Cardinal Primitives -- canonical)
4. swift-algebra-field-primitives (only imported Algebra Primitives -- canonical)
5. swift-algebra-group-primitives (only imported Algebra Primitives -- canonical)
6. swift-algebra-law-primitives (only imported Algebra Modular, Finite, Algebra Cardinal, Algebra Affine -- all canonical)
7. swift-algebra-linear-primitives (only imported Dimension Primitives -- canonical)
8. swift-algebra-magma-primitives (only imported Algebra Primitives -- canonical)
9. swift-bit-pack-primitives (Bit, Bit Index -- canonical; source: Index -- canonical)
10. swift-bit-primitives (Finite, Cardinal -- canonical; source: Identity -- canonical)
11. swift-cardinal-primitives (only imported Identity Primitives -- canonical)
12. swift-clock-primitives (only imported Identity Primitives -- canonical)
13. swift-comparison-primitives (only imported Identity Primitives -- canonical)
14. swift-complex-primitives (only imported Dimension Primitives -- canonical)
15. swift-continuation-primitives (only imported Identity Primitives -- canonical)
16. swift-cyclic-index-primitives (Cyclic, Index -- both canonical; source: Cyclic -- canonical)
17. swift-diagnostic-primitives (only imported Source Primitives -- canonical)
18. swift-equation-primitives (only imported Identity Primitives -- canonical)
19. swift-formatting-primitives (only imported Identity Primitives -- canonical)
20. swift-handle-primitives (Identity, Index, Bit -- all canonical)
21. swift-hash-primitives (only imported Identity Primitives -- canonical)
22. swift-infinite-primitives (only imported Input Primitives -- canonical)
23. swift-input-primitives (Identity, Index -- both canonical)
24. swift-layout-primitives (Dimension, Geometry -- both canonical)
25. swift-lexer-primitives (only imported Token Primitives -- canonical)
26. swift-link-primitives (Index, Vector -- both canonical; source: Index, Vector -- canonical)
27. swift-list-primitives (Index, Input -- both canonical)
28. swift-matrix-primitives (Vector, Dimension, Index -- all canonical)
29. swift-module-primitives (only imported Source Primitives -- canonical)
30. swift-numeric-primitives (only imported Identity Primitives -- canonical)
31. swift-ordinal-primitives (Identity, Cardinal -- both canonical)
32. swift-path-primitives (only imported Identity Primitives -- canonical)
33. swift-range-primitives (only imported Vector Primitives -- canonical)
34. swift-region-primitives (Dimension, Algebra -- both canonical; source: Algebra -- canonical)
35. swift-scalar-primitives (only imported Identity Primitives -- canonical)
36. swift-sequence-primitives (only imported Index Primitives -- canonical)
37. swift-source-primitives (only imported Text Primitives -- canonical)
38. swift-space-primitives (only imported Dimension Primitives -- canonical)
39. swift-state-primitives (only imported Identity Primitives -- canonical)
40. swift-structured-queries-primitives (only imported Identity Primitives -- canonical)
41. swift-symbol-primitives (only imported Text Primitives -- canonical)
42. swift-syntax-primitives (only imported Token Primitives -- canonical)
43. swift-system-primitives (only imported Cardinal Primitives -- canonical)
44. swift-time-primitives (only imported Dimension Primitives -- canonical)
45. swift-token-primitives (only imported Text Primitives -- canonical)

**Total clean: 45 packages**

---

## Packages with true violations (BANNED umbrella imports)

---

### swift-abi-primitives

**Banned umbrella**: Binary Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 29 | `Binary Primitives` | (main target) | `Binary Primitives Core` -- uses `Binary` namespace, `Binary.Aligned`, error types |

No source file violations.

---

### swift-affine-geometry-primitives

**Banned umbrella**: Affine Primitives (Dimension Primitives is canonical -- no change needed)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 28 | `Affine Primitives` | Affine Geometry Primitives | `Affine Primitives Core` -- uses `Affine.Continuous`, `Affine.Discrete.Ratio` |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Affine.Continuous.swift | `import Affine_Primitives` | `Affine` namespace (declares `Affine.Continuous`) | `import Affine_Primitives_Core` |
| Affine.Continuous+Arithmetic.swift | `import Affine_Primitives` | `Affine.Continuous.Point` arithmetic extensions | `import Affine_Primitives_Core` |
| Affine.Continuous+Formatting.swift | `import Affine_Primitives` | `Affine.Continuous` formatting extensions | `import Affine_Primitives_Core` |
| Affine.Continuous.Point+Real.swift | `import Affine_Primitives` | `Affine.Continuous.Point` extensions | `import Affine_Primitives_Core` |
| Affine.Continuous.Point.swift | `import Affine_Primitives` | `Affine.Continuous` (extends with `.Point`) | `import Affine_Primitives_Core` |
| Affine.Continuous.Transform.swift | `import Affine_Primitives` | `Affine.Continuous` (extends with `.Transform`) | `import Affine_Primitives_Core` |
| Affine.Continuous.Translation.swift | `import Affine_Primitives` | `Affine.Continuous` (extends with `.Translation`) | `import Affine_Primitives_Core` |

---

### swift-algebra-modular-primitives

**Banned umbrella**: Affine Primitives (Finite, Identity are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 34 | `Affine Primitives` | Algebra Modular Primitives | `Affine Primitives Core` -- uses `Affine.Discrete.Ratio`, `Affine.Discrete.Vector` for modular arithmetic |

No source file violations.

---

### swift-base62-primitives

**Banned umbrella**: Binary Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 27 | `Binary Primitives` | (main target) | `Binary Primitives Core` -- uses `Binary` namespace for byte encoding/decoding |

No source file violations.

---

### swift-binary-primitives

**Banned umbrella**: Memory Primitives (Bit, Dimension, Index are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 57 | `Memory Primitives` | Binary Primitives Core | `Memory Primitives Core` -- uses `Memory.Alignment`, `Memory.Contiguous.Protocol` |

No source file violations.

---

### swift-bit-index-primitives

**Banned umbrella**: Affine Primitives (Bit, Index, Ordinal are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 36 | `Affine Primitives` | Bit Index Primitives | `Affine Primitives Core` -- uses `Affine.Discrete.Ratio` for bit-to-word ratio |

No source file violations.

---

### swift-bitset-primitives

**Banned umbrella**: Sequence Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 27 | `Sequence Primitives` | (main target) | `Sequence Primitives Core` -- uses `Sequence.Protocol`, `Sequence.Iterator.Protocol` |

No source file violations.

---

### swift-cache-primitives

**Banned umbrellas**: Array, Async, Time (Index is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 37 | `Array Primitives` | Cache Primitives | `Array Primitives Core` -- uses `Array` for cache storage |
| 38 | `Async Primitives` | Cache Primitives | `Async Primitives Core` -- uses async lifecycle/channel primitives |
| 43 | `Time Primitives` | Cache Primitives | `Time Primitives Core` -- uses `Duration`, `Instant` for TTL/expiry |

No source file violations.

---

### swift-collection-primitives

**Banned umbrella**: Sequence Primitives (Index is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 39 | `Sequence Primitives` | Collection Primitives | `Sequence Primitives Core` -- uses `Sequence.Protocol`, `Sequence.Iterator.Protocol` |

No source file violations.

---

### swift-cpu-primitives

**Banned umbrella**: Binary Primitives (Bit, Dimension are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 34 | `Binary Primitives` | CPU Primitives | `Binary Primitives Core` -- uses `Binary.Endianness`, `Binary.Mask`, `Binary.Pattern` |

No source file violations.

---

### swift-cyclic-primitives

**Banned umbrella**: Sequence Primitives (Ordinal, Cardinal are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 39 | `Sequence Primitives` | Cyclic Primitives | `Sequence Primitives Core` -- uses `Sequence.Protocol`, `Sequence.Iterator.Protocol` |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Cyclic.Group.Static+Sequence.Protocol.swift | `import Sequence_Primitives` | `Sequence.Protocol` conformance | `import Sequence_Primitives_Core` |
| Cyclic.Group.Static.Iterator.swift | `import Sequence_Primitives` | `Sequence.Iterator.Protocol` conformance | `import Sequence_Primitives_Core` |

---

### swift-darwin-primitives

**Banned umbrella**: Kernel Primitives (Dimension is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 67 | `Kernel Primitives` | Darwin Primitives | **Requires source audit** -- likely needs multiple kernel variants: `Kernel Primitives Core`, `Kernel File Primitives`, `Kernel Memory Primitives`, `Kernel Descriptor Primitives`, `Kernel IO Primitives`, `Kernel Event Primitives`, etc. |

No source file violations.

---

### swift-dictionary-primitives

**Banned umbrella**: Sequence Primitives (Set, Hash Table, Index, Input are all canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 56 | `Sequence Primitives` | Dictionary Ordered Primitives | `Sequence Primitives Core` |
| 67 | `Sequence Primitives` | Dictionary Inline Primitives | `Sequence Primitives Core` |
| 76 | `Sequence Primitives` | Dictionary Static Primitives | `Sequence Primitives Core` |

No BANNED source file violations (Index, Set, Hash Table imports are all canonical).

---

### swift-dimension-primitives

**Banned umbrella**: Numeric Primitives (Finite, Identity are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 36 | `Numeric Primitives` | Dimension Primitives | `Numeric Primitives Core` -- uses `Numeric.Quantized` protocol |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Tagged+Quantized.swift | `import Numeric_Primitives` | `Numeric.Quantized` protocol | `import Numeric_Primitives_Core` |

---

### swift-endian-primitives

**Banned umbrella**: Binary Primitives (Bit is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 29 | `Binary Primitives` | Endian Primitives | `Binary Primitives Core` -- uses `Binary.Endianness` |

No source file violations.

---

### swift-geometry-primitives

**Banned umbrella**: Affine Primitives (Dimension is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 38 | `Affine Primitives` | Geometry Primitives | `Affine Primitives Core` -- uses `Affine.Continuous.Point`, affine namespace |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Geometry.Arc.swift | `import Affine_Primitives` | `Affine.Continuous.Point` (indirectly via Affine Geometry) | `import Affine_Primitives_Core` |
| Geometry.Ball.swift | `import Affine_Primitives` | `Affine.Continuous.Point` | `import Affine_Primitives_Core` |
| Geometry.Ellipse.swift | `import Affine_Primitives` | `Affine.Continuous.Point` | `import Affine_Primitives_Core` |
| Geometry.Line.swift | `import Affine_Primitives` | `Affine.Continuous.Point` | `import Affine_Primitives_Core` |
| Geometry.swift | `import Affine_Primitives` (public) | `Affine` namespace re-export | `public import Affine_Primitives_Core` |

---

### swift-hash-table-primitives

**Banned umbrella**: Sequence Primitives (Index, Ordinal, Cardinal, Cyclic Index, Finite are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 59 | `Sequence Primitives` | Hash Table Dynamic Primitives | `Sequence Primitives Core` |

No BANNED source file violations (Cardinal imports are canonical).

---

### swift-heap-primitives

**Banned umbrella**: Sequence Primitives (Index is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 85 | `Sequence Primitives` | Heap Binary Primitives | `Sequence Primitives Core` |
| 94 | `Sequence Primitives` | Heap Fixed Primitives | `Sequence Primitives Core` |
| 103 | `Sequence Primitives` | Heap Static Primitives | `Sequence Primitives Core` |
| 112 | `Sequence Primitives` | Heap Small Primitives | `Sequence Primitives Core` |
| 133 | `Sequence Primitives` | Heap MinMax Primitives | `Sequence Primitives Core` |

No source file violations.

---

### swift-index-primitives

**Banned umbrella**: Affine Primitives (Ordinal, Cardinal, Identity are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 44 | `Affine Primitives` | Index Primitives Core | `Affine Primitives Core` -- uses `Affine.Discrete.Vector`, `Affine.Discrete.Ratio` for index arithmetic |

No source file violations.

---

### swift-kernel-primitives

**Banned umbrellas**: Binary, Time (Cardinal, Dimension are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 146 | `Binary Primitives` | Kernel Primitives Core | `Binary Primitives Core` -- uses `Binary.Endianness`, `Binary.Count`, `Binary.Space` |
| 154 | `Time Primitives` | Kernel Primitives Core | `Time Primitives Core` -- uses `Time`, `Duration`, `Instant` |

No source file violations.

---

### swift-linux-primitives

**Banned umbrella**: Kernel Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 68 | `Kernel Primitives` | Linux Primitives | **Requires source audit** -- likely needs multiple kernel variants: `Kernel Primitives Core`, `Kernel File Primitives`, `Kernel IO Primitives`, `Kernel Socket Primitives`, `Kernel Thread Primitives`, etc. |

No source file violations.

---

### swift-machine-primitives

**Banned umbrella**: Graph Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 184 | `Graph Primitives` | Machine Primitives | `Graph Primitives Core` -- uses `Graph.Node` for machine program graph |

No source file violations.

---

### swift-memory-primitives

**Banned umbrellas**: Affine, Bit Vector (Ordinal, Cardinal, Identity, Bit, Index are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 73 | `Affine Primitives` | Memory Primitives Core | `Affine Primitives Core` -- uses `Affine.Discrete.Ratio` for stride computation |
| 96 | `Bit Vector Primitives` | Memory Pool Primitives | `Bit Vector Primitives Core` -- uses `Bit.Vector` for slot bitmap tracking |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Memory.Address.swift | `import Affine_Primitives` | `Affine.Discrete.Ratio` (stride ratio) | `import Affine_Primitives_Core` |

Note: `import Cardinal_Primitives` in same file is canonical -- no change.

---

### swift-network-primitives

**Banned umbrellas**: Binary, Kernel

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 30 | `Binary Primitives` | Network Primitives | `Binary Primitives Core` -- uses `Binary.Endianness`, byte manipulation |
| 32 | `Kernel Primitives` | Network Primitives | **Requires source audit** -- likely needs `Kernel Socket Primitives`, `Kernel IO Primitives`, `Kernel Descriptor Primitives` |

No source file violations.

---

### swift-parser-primitives

**Banned umbrella**: Array Primitives (Input, Algebra, Text are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 179 | `Array Primitives` | Parser Primitives Core | `Array Primitives Core` -- re-exports Array type for parser combinator storage |
| 509 | `Array Primitives` | Parser Conformance Primitives | `Array Primitives Core` -- `Swift.Array: Parser.Protocol` conformance |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Parser.Literal.swift | `import Array_Primitives` | `[UInt8]` via Array re-export for literal byte storage | `import Array_Primitives_Core` |

Note: `import Algebra_Primitives` in Parser.Either.swift is canonical -- no change.

---

### swift-pool-primitives

**Banned umbrellas**: Async, Array (Dimension is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 49 | `Async Primitives` | Pool Primitives Core | `Async Primitives Core` -- uses `Async.Lifecycle` for pool lifecycle management |
| 62 | `Array Primitives` | Pool Bounded Primitives | `Array Primitives Core` -- uses `Array` for pool resource storage |

No source file violations.

---

### swift-queue-primitives

**Banned umbrellas**: Buffer, List (Index, Vector, Input are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 47 | `Buffer Primitives` | Queue Primitives Core | `Buffer Ring Primitives Core` + `Buffer Linked Primitives Core` -- uses `Buffer.Ring` and `Buffer.Linked` for queue backing |
| 52 | `List Primitives` | Queue Primitives Core | `List Primitives Core` -- uses `List.Linked` for linked-list queue variant |

#### Source file changes

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| Queue.swift | `import List_Primitives` | `List.Linked` (namespace, type) | `import List_Primitives_Core` |

Note: `import Vector_Primitives` in same file is canonical -- no change.

---

### swift-stack-primitives

**Banned umbrella**: Sequence Primitives (Index, Finite are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 72 | `Sequence Primitives` | Stack Dynamic Primitives | `Sequence Primitives Core` |
| 82 | `Sequence Primitives` | Stack Fixed Primitives | `Sequence Primitives Core` |
| 93 | `Sequence Primitives` | Stack Static Primitives | `Sequence Primitives Core` |
| 105 | `Sequence Primitives` | Stack Small Primitives | `Sequence Primitives Core` |

No source file violations.

---

### swift-string-primitives

**Banned umbrella**: Memory Primitives (Identity is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 30 | `Memory Primitives` | String Primitives | `Memory Primitives Core` -- uses `Memory.Contiguous.Protocol`, `Memory.Inline` |

No source file violations.

---

### swift-symmetry-primitives

**Banned umbrella**: Affine Primitives (Algebra, Cardinal, Dimension, Finite, Ordinal are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 39 | `Affine Primitives` | Symmetry Primitives | `Affine Primitives Core` -- uses `Affine.Discrete.Vector` for symmetry group operations |

No source file violations.

---

### swift-terminal-primitives

**Banned umbrella**: Kernel Primitives (Input is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 42 | `Kernel Primitives` | Terminal Primitives | **Requires source audit** -- likely needs `Kernel Terminal Primitives`, `Kernel Descriptor Primitives`, `Kernel IO Primitives` |

No source file violations.

---

### swift-test-primitives

**Banned umbrellas**: Time, Async (Identity, Source, Sample are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 51 | `Time Primitives` | Test Primitives Core | `Time Primitives Core` -- uses `Duration`, `Instant` for benchmark measurement |
| 60 | `Async Primitives` | Test Snapshot Primitives | `Async Primitives Core` -- uses async test infrastructure |

No BANNED source file violations (Sample imports are canonical).

---

### swift-text-primitives

**Banned umbrella**: Affine Primitives

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 31 | `Affine Primitives` | Text Primitives | `Affine Primitives Core` -- uses `Affine.Discrete.Vector` for text position/offset |

No source file violations.

---

### swift-tree-primitives

**Banned umbrellas**: Queue, Array (Index is canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 66 | `Queue Primitives` | Tree Primitives Core | `Queue Primitives Core` -- uses `Queue` for level-order traversal BFS |
| 136 | `Array Primitives` | Tree Keyed Primitives | `Array Primitives Core` -- uses `Array` for child storage |

No source file violations.

---

### swift-vector-primitives

**Banned umbrella**: Sequence Primitives (Index, Cyclic are canonical)

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 37 | `Sequence Primitives` | Vector Primitives | `Sequence Primitives Core` -- uses `Sequence.Protocol`, `Sequence.Iterator.Protocol` |

No source file violations.

---

### swift-windows-primitives

**Banned umbrellas**: Kernel, Sequence

#### Package.swift changes

| Line | Current product | Target | Replacement product |
|------|----------------|--------|-------------------|
| 53 | `Kernel Primitives` | Windows Primitives | **Requires source audit** -- likely needs `Kernel Primitives Core`, `Kernel File Primitives`, `Kernel IO Primitives`, `Kernel Socket Primitives` |
| 55 | `Sequence Primitives` | Windows Primitives | `Sequence Primitives Core` |

No source file violations.

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Packages clean after filtering | 45 |
| Packages with true BANNED violations | 37 |
| -- Package.swift-only changes | 30 |
| -- Source + Package.swift changes | 7 |

### Remediation complexity

| Complexity | Packages |
|------------|----------|
| **Trivial** (1 line, direct variant known) | swift-abi, swift-algebra-modular, swift-base62, swift-binary (memory), swift-bit-index, swift-bitset, swift-collection, swift-cpu, swift-endian, swift-hash-table, swift-index, swift-machine, swift-string, swift-symmetry, swift-text, swift-vector (16 packages) |
| **Simple** (2-3 lines, variants known) | swift-cache, swift-kernel, swift-memory, swift-pool, swift-queue, swift-test, swift-tree, swift-dictionary, swift-parser-primitives, swift-heap, swift-stack, swift-network, swift-windows (13 packages) |
| **Needs source audit** (kernel umbrella with many possible variants) | swift-darwin, swift-linux, swift-terminal, swift-network (kernel portion), swift-windows (kernel portion) (5 audit points across 4 packages) |
| **Source + Package.swift** (both types of changes) | swift-affine-geometry (7 src + 1 pkg), swift-geometry (5 src + 1 pkg), swift-cyclic (2 src + 1 pkg), swift-dimension (1 src + 1 pkg), swift-memory (1 src + 2 pkg), swift-parser-primitives (1 src + 2 pkg), swift-queue (1 src + 2 pkg) |

### Most common replacements

| Banned umbrella | Replacement variant | Occurrences |
|-----------------|-------------------|-------------|
| Sequence Primitives | Sequence Primitives Core | 19 Package.swift + 2 source |
| Affine Primitives | Affine Primitives Core | 8 Package.swift + 13 source |
| Binary Primitives | Binary Primitives Core | 5 Package.swift |
| Kernel Primitives | Multiple variants (needs audit) | 5 Package.swift |
| Array Primitives | Array Primitives Core | 4 Package.swift + 1 source |
| Time Primitives | Time Primitives Core | 3 Package.swift |
| Async Primitives | Async Primitives Core | 3 Package.swift |
| Memory Primitives | Memory Primitives Core | 3 Package.swift |
| Numeric Primitives | Numeric Primitives Core | 1 Package.swift + 1 source |
| Queue Primitives | Queue Primitives Core | 1 Package.swift |
| List Primitives | List Primitives Core | 1 Package.swift + 1 source |
| Graph Primitives | Graph Primitives Core | 1 Package.swift |
| Bit Vector Primitives | Bit Vector Primitives Core | 1 Package.swift |
| Buffer Primitives | Ring/Linked Core variants | 1 Package.swift |
