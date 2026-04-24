# Umbrella Import Violations

**Scan date**: 2026-04-03
**Total violations**: 471 (272 Package.swift deps + 199 source imports)
**Packages with violations**: 93

## Per-Package Summary

| Package | Umbrella Deps in Package.swift | Umbrella Imports in Source | Total Violations |
|---------|---:|---:|---:|
| swift-abi-primitives | 1 | 0 | 1 |
| swift-abstract-syntax-tree-primitives | 1 | 0 | 1 |
| swift-affine-geometry-primitives | 2 | 7 | 9 |
| swift-affine-primitives | 2 | 0 | 2 |
| swift-algebra-affine-primitives | 1 | 0 | 1 |
| swift-algebra-cardinal-primitives | 1 | 0 | 1 |
| swift-algebra-field-primitives | 1 | 0 | 1 |
| swift-algebra-group-primitives | 1 | 0 | 1 |
| swift-algebra-law-primitives | 4 | 0 | 4 |
| swift-algebra-linear-primitives | 1 | 0 | 1 |
| swift-algebra-magma-primitives | 1 | 0 | 1 |
| swift-algebra-modular-primitives | 3 | 0 | 3 |
| swift-array-primitives | 3 | 9 | 12 |
| swift-async-primitives | 3 | 7 | 10 |
| swift-base62-primitives | 1 | 0 | 1 |
| swift-binary-parser-primitives | 3 | 12 | 15 |
| swift-binary-primitives | 4 | 0 | 4 |
| swift-bit-index-primitives | 4 | 0 | 4 |
| swift-bit-pack-primitives | 2 | 3 | 5 |
| swift-bit-primitives | 2 | 1 | 3 |
| swift-bit-vector-primitives | 3 | 21 | 24 |
| swift-bitset-primitives | 1 | 0 | 1 |
| swift-buffer-primitives | 18 | 22 | 40 |
| swift-cache-primitives | 4 | 0 | 4 |
| swift-cardinal-primitives | 1 | 0 | 1 |
| swift-clock-primitives | 1 | 0 | 1 |
| swift-collection-primitives | 2 | 0 | 2 |
| swift-comparison-primitives | 1 | 0 | 1 |
| swift-complex-primitives | 1 | 0 | 1 |
| swift-continuation-primitives | 1 | 0 | 1 |
| swift-cpu-primitives | 3 | 0 | 3 |
| swift-cyclic-index-primitives | 2 | 2 | 4 |
| swift-cyclic-primitives | 3 | 2 | 5 |
| swift-darwin-primitives | 2 | 0 | 2 |
| swift-diagnostic-primitives | 1 | 0 | 1 |
| swift-dictionary-primitives | 7 | 3 | 10 |
| swift-dimension-primitives | 3 | 3 | 6 |
| swift-endian-primitives | 2 | 0 | 2 |
| swift-equation-primitives | 1 | 0 | 1 |
| swift-finite-primitives | 5 | 12 | 17 |
| swift-formatting-primitives | 1 | 0 | 1 |
| swift-geometry-primitives | 2 | 5 | 7 |
| swift-graph-primitives | 24 | 1 | 25 |
| swift-handle-primitives | 3 | 0 | 3 |
| swift-hash-primitives | 1 | 0 | 1 |
| swift-hash-table-primitives | 6 | 2 | 8 |
| swift-heap-primitives | 6 | 0 | 6 |
| swift-index-primitives | 4 | 0 | 4 |
| swift-infinite-primitives | 1 | 0 | 1 |
| swift-input-primitives | 2 | 0 | 2 |
| swift-kernel-primitives | 4 | 0 | 4 |
| swift-layout-primitives | 2 | 0 | 2 |
| swift-lexer-primitives | 1 | 0 | 1 |
| swift-link-primitives | 2 | 5 | 7 |
| swift-linux-primitives | 1 | 0 | 1 |
| swift-list-primitives | 2 | 0 | 2 |
| swift-machine-primitives | 1 | 0 | 1 |
| swift-matrix-primitives | 3 | 0 | 3 |
| swift-memory-primitives | 7 | 2 | 9 |
| swift-module-primitives | 1 | 0 | 1 |
| swift-network-primitives | 2 | 0 | 2 |
| swift-numeric-primitives | 1 | 0 | 1 |
| swift-ordinal-primitives | 2 | 0 | 2 |
| swift-parser-machine-primitives | 4 | 10 | 14 |
| swift-parser-primitives | 5 | 2 | 7 |
| swift-path-primitives | 1 | 0 | 1 |
| swift-pool-primitives | 3 | 0 | 3 |
| swift-queue-primitives | 5 | 2 | 7 |
| swift-range-primitives | 1 | 0 | 1 |
| swift-region-primitives | 2 | 7 | 9 |
| swift-scalar-primitives | 1 | 0 | 1 |
| swift-sequence-primitives | 1 | 0 | 1 |
| swift-set-primitives | 10 | 37 | 47 |
| swift-slab-primitives | 5 | 14 | 19 |
| swift-source-primitives | 1 | 0 | 1 |
| swift-space-primitives | 1 | 0 | 1 |
| swift-stack-primitives | 6 | 0 | 6 |
| swift-state-primitives | 1 | 0 | 1 |
| swift-storage-primitives | 13 | 3 | 16 |
| swift-string-primitives | 2 | 0 | 2 |
| swift-structured-queries-primitives | 1 | 0 | 1 |
| swift-symbol-primitives | 1 | 0 | 1 |
| swift-symmetry-primitives | 6 | 0 | 6 |
| swift-syntax-primitives | 1 | 0 | 1 |
| swift-system-primitives | 1 | 0 | 1 |
| swift-terminal-primitives | 2 | 0 | 2 |
| swift-test-primitives | 5 | 5 | 10 |
| swift-text-primitives | 1 | 0 | 1 |
| swift-time-primitives | 1 | 0 | 1 |
| swift-token-primitives | 1 | 0 | 1 |
| swift-tree-primitives | 3 | 0 | 3 |
| swift-vector-primitives | 3 | 0 | 3 |
| swift-windows-primitives | 2 | 0 | 2 |

| **TOTAL** | **272** | **199** | **471** |

## Detailed Findings

### swift-abi-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`

### swift-abstract-syntax-tree-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Source Primitives", package: "swift-source-primitives")` -- should use specific variant(s) of `Source_Primitives`

### swift-affine-geometry-primitives

**Package.swift violations:**
- Line 28: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 30: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

**Source file violations:**
- `Sources/Affine Geometry Primitives/Affine.Continuous+Arithmetic.swift`: `import Affine_Primitives` (line 8)
- `Sources/Affine Geometry Primitives/Affine.Continuous+Formatting.swift`: `import Affine_Primitives` (line 9)
- `Sources/Affine Geometry Primitives/Affine.Continuous.Point+Real.swift`: `import Affine_Primitives` (line 4)
- `Sources/Affine Geometry Primitives/Affine.Continuous.Point.swift`: `import Affine_Primitives` (line 4)
- `Sources/Affine Geometry Primitives/Affine.Continuous.Transform.swift`: `import Affine_Primitives` (line 4)
- `Sources/Affine Geometry Primitives/Affine.Continuous.Translation.swift`: `import Affine_Primitives` (line 4)
- `Sources/Affine Geometry Primitives/Affine.Continuous.swift`: `import Affine_Primitives` (line 12)

### swift-affine-primitives

**Package.swift violations:**
- Line 41: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 42: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`

### swift-algebra-affine-primitives

**Package.swift violations:**
- Line 33: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`

### swift-algebra-cardinal-primitives

**Package.swift violations:**
- Line 33: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`

### swift-algebra-field-primitives

**Package.swift violations:**
- Line 30: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`

### swift-algebra-group-primitives

**Package.swift violations:**
- Line 30: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`

### swift-algebra-law-primitives

**Package.swift violations:**
- Line 46: `.product(name: "Algebra Modular Primitives", package: "swift-algebra-modular-primitives"),` -- should use specific variant(s) of `Algebra_Modular_Primitives`
- Line 47: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 54: `.product(name: "Algebra Cardinal Primitives", package: "swift-algebra-cardinal-primitives"),` -- should use specific variant(s) of `Algebra_Cardinal_Primitives`
- Line 61: `.product(name: "Algebra Affine Primitives", package: "swift-algebra-affine-primitives"),` -- should use specific variant(s) of `Algebra_Affine_Primitives`

### swift-algebra-linear-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

### swift-algebra-magma-primitives

**Package.swift violations:**
- Line 28: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`

### swift-algebra-modular-primitives

**Package.swift violations:**
- Line 34: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 36: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 37: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-array-primitives

**Package.swift violations:**
- Line 66: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 79: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 113: `.product(name: "Algebra Modular Primitives", package: "swift-algebra-modular-primitives"),` -- should use specific variant(s) of `Algebra_Modular_Primitives`

**Source file violations:**
- `Sources/Array Dynamic Primitives/Array.Dynamic ~Copyable.swift`: `import Index_Primitives` (line 16)
- `Sources/Array Dynamic Primitives/Array.Dynamic.Indexed.swift`: `import Index_Primitives` (line 13)
- `Sources/Array Fixed Primitives/Array.Fixed Copyable.swift`: `import Index_Primitives` (line 14)
- `Sources/Array Small Primitives/Array.Small.Indexed.swift`: `import Index_Primitives` (line 13)
- `Sources/Array Static Primitives/Array Static.swift`: `import Index_Primitives` (line 14)
- `Sources/Array Static Primitives/Array Static.swift`: `import Sequence_Primitives` (line 15)
- `Sources/Array Static Primitives/Array.Static ~Copyable.swift`: `import Index_Primitives` (line 14)
- `Sources/Array Static Primitives/Array.Static ~Copyable.swift`: `import Sequence_Primitives` (line 16)
- `Sources/Array Static Primitives/Array.Static.Indexed.swift`: `import Index_Primitives` (line 12)

### swift-async-primitives

**Package.swift violations:**
- Line 87: `.product(name: "Buffer Primitives", package: "swift-buffer-primitives"),` -- should use specific variant(s) of `Buffer_Primitives`
- Line 88: `.product(name: "Queue Primitives", package: "swift-queue-primitives"),` -- should use specific variant(s) of `Queue_Primitives`
- Line 89: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

**Source file violations:**
- `Sources/Async Bridge Primitives/Async.Bridge.swift`: `import Queue_Primitives` (line 16)
- `Sources/Async Broadcast Primitives/Async.Broadcast.State.swift`: `import Queue_Primitives` (line 16)
- `Sources/Async Broadcast Primitives/Async.Broadcast.swift`: `import Queue_Primitives` (line 16)
- `Sources/Async Timer Primitives/Async.Timer.Wheel+Slot.swift`: `import Buffer_Primitives` (line 12)
- `Sources/Async Timer Primitives/Async.Timer.Wheel.Level.swift`: `import Buffer_Primitives` (line 12)
- `Sources/Async Timer Primitives/Async.Timer.Wheel.Payload.swift`: `import Buffer_Primitives` (line 12)
- `Sources/Async Timer Primitives/Async.Timer.Wheel.Storage.swift`: `import Buffer_Primitives` (line 12)

### swift-base62-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Binary Primitives", package: "swift-binary-primitives")` -- should use specific variant(s) of `Binary_Primitives`

### swift-binary-parser-primitives

**Package.swift violations:**
- Line 72: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`
- Line 73: `.product(name: "Parser Primitives", package: "swift-parser-primitives"),` -- should use specific variant(s) of `Parser_Primitives`
- Line 99: `.product(name: "Machine Primitives", package: "swift-machine-primitives"),` -- should use specific variant(s) of `Machine_Primitives`

**Source file violations:**
- `Sources/Binary Input View Primitives/Binary.Bytes.Input.View+typed.swift`: `import Index_Primitives` (line 1)
- `Sources/Binary Integer Primitives/Int16+Parser.swift`: `import Input_Primitives` (line 8)
- `Sources/Binary Integer Primitives/Int32+Parser.swift`: `import Input_Primitives` (line 8)
- `Sources/Binary Integer Primitives/Int64+Parser.swift`: `import Input_Primitives` (line 8)
- `Sources/Binary Integer Primitives/Int8+Parser.swift`: `import Input_Primitives` (line 8)
- `Sources/Binary Integer Primitives/UInt8+Parser.swift`: `import Input_Primitives` (line 8)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Error.swift`: `import Machine_Primitives` (line 4)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Error.swift`: `import Parser_Primitives` (line 5)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Frame.swift`: `import Index_Primitives` (line 5)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Instruction.swift`: `import Machine_Primitives` (line 4)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Node.swift`: `import Tagged_Primitives` (line 5)
- `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Program.swift`: `import Tagged_Primitives` (line 5)

### swift-binary-primitives

**Package.swift violations:**
- Line 54: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 55: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 56: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 57: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`

### swift-bit-index-primitives

**Package.swift violations:**
- Line 34: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 35: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 36: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 37: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`

### swift-bit-pack-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 33: `.product(name: "Bit Index Primitives", package: "swift-bit-index-primitives"),` -- should use specific variant(s) of `Bit_Index_Primitives`

**Source file violations:**
- `Sources/Bit Pack Primitives/Bit.Index+Pack.swift`: `import Index_Primitives` (line 13)
- `Sources/Bit Pack Primitives/Bit.Pack.Words.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Pack Primitives/Bit.Pack.swift`: `import Index_Primitives` (line 12)

### swift-bit-primitives

**Package.swift violations:**
- Line 40: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 64: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`

**Source file violations:**
- `Sources/Bit Primitives/Bit.Order.Value.swift`: `import Tagged_Primitives` (line 8)

### swift-bit-vector-primitives

**Package.swift violations:**
- Line 59: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 60: `.product(name: "Bit Pack Primitives", package: "swift-bit-pack-primitives"),` -- should use specific variant(s) of `Bit_Pack_Primitives`
- Line 62: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+growth.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded+mutating.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Bounded.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Ones.Bounded.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Bounded Primitives/Bit.Vector.Zeros.Bounded.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+conversions.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+growth.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic+mutating.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Dynamic Primitives/Bit.Vector.Dynamic.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+growth.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Inline+mutating.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Inline.swift`: `import Affine_Primitives` (line 12)
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Ones.Inline.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Inline Primitives/Bit.Vector.Zeros.Inline.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector+ones.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector+zeros.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector.Ones.View.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector.Ones.View.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector.Protocol+defaults.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector.Zeros.View.Iterator.swift`: `import Index_Primitives` (line 12)
- `Sources/Bit Vector Primitives Core/Bit.Vector.Zeros.View.swift`: `import Index_Primitives` (line 12)

### swift-bitset-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

### swift-buffer-primitives

**Package.swift violations:**
- Line 94: `.product(name: "Link Primitives", package: "swift-link-primitives"),` -- should use specific variant(s) of `Link_Primitives`
- Line 95: `.product(name: "Storage Primitives", package: "swift-storage-primitives"),` -- should use specific variant(s) of `Storage_Primitives`
- Line 96: `.product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),` -- should use specific variant(s) of `Cyclic_Index_Primitives`
- Line 97: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`
- Line 98: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 128: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 137: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 147: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 148: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 158: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 159: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 170: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 181: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 190: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 200: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 209: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 228: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 237: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Buffer Arena Primitives Core/Buffer.Arena.Bounded.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Arena Primitives Core/Buffer.Arena.Position.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Arena Primitives Core/Buffer.Arena.Small.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Arena Primitives Core/Buffer.Arena.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Linear Inline Primitives/Buffer.Linear.Inline+Subscript.swift`: `import Finite_Primitives` (line 1)
- `Sources/Buffer Linear Primitives Core/Buffer.Linear.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Header.swift`: `import Link_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Inline.swift`: `import Vector_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Inline.swift`: `import Index_Primitives` (line 2)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Node.swift`: `import Link_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Small.swift`: `import Vector_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.Small.swift`: `import Index_Primitives` (line 2)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.swift`: `import Vector_Primitives` (line 1)
- `Sources/Buffer Linked Primitives Core/Buffer.Linked.swift`: `import Index_Primitives` (line 2)
- `Sources/Buffer Primitives Core/Buffer.swift`: `import Vector_Primitives` (line 1)
- `Sources/Buffer Primitives Core/Buffer.swift`: `import Index_Primitives` (line 2)
- `Sources/Buffer Ring Primitives Core/Buffer.Ring.Checkpoint.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Ring Primitives Core/Buffer.Ring.Small.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Ring Primitives Core/Buffer.Ring.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Ring Primitives/Storage.Initialization.swift`: `import Storage_Primitives` (line 9)
- `Sources/Buffer Slab Primitives Core/Buffer.Slab.swift`: `import Index_Primitives` (line 1)
- `Sources/Buffer Slots Primitives Core/Buffer.Slots.swift`: `import Index_Primitives` (line 1)

### swift-cache-primitives

**Package.swift violations:**
- Line 37: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`
- Line 38: `.product(name: "Async Primitives", package: "swift-async-primitives"),` -- should use specific variant(s) of `Async_Primitives`
- Line 42: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 43: `.product(name: "Time Primitives", package: "swift-time-primitives"),` -- should use specific variant(s) of `Time_Primitives`

### swift-cardinal-primitives

**Package.swift violations:**
- Line 35: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-clock-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-collection-primitives

**Package.swift violations:**
- Line 36: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 39: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

### swift-comparison-primitives

**Package.swift violations:**
- Line 38: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-complex-primitives

**Package.swift violations:**
- Line 26: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

### swift-continuation-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-cpu-primitives

**Package.swift violations:**
- Line 34: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`
- Line 35: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 36: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

### swift-cyclic-index-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Cyclic Primitives", package: "swift-cyclic-primitives"),` -- should use specific variant(s) of `Cyclic_Primitives`
- Line 33: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`

**Source file violations:**
- `Sources/Cyclic Index Primitives/Index.Cyclic.swift`: `import Cyclic_Primitives` (line 12)
- `Sources/Cyclic Index Primitives/Index.Modular.swift`: `import Cyclic_Primitives` (line 12)

### swift-cyclic-primitives

**Package.swift violations:**
- Line 37: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 38: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 39: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Cyclic Primitives/Cyclic.Group.Static+Sequence.Protocol.swift`: `import Sequence_Primitives` (line 12)
- `Sources/Cyclic Primitives/Cyclic.Group.Static.Iterator.swift`: `import Sequence_Primitives` (line 12)

### swift-darwin-primitives

**Package.swift violations:**
- Line 67: `.product(name: "Kernel Primitives", package: "swift-kernel-primitives"),` -- should use specific variant(s) of `Kernel_Primitives`
- Line 68: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives")` -- should use specific variant(s) of `Dimension_Primitives`

### swift-diagnostic-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Source Primitives", package: "swift-source-primitives")` -- should use specific variant(s) of `Source_Primitives`

### swift-dictionary-primitives

**Package.swift violations:**
- Line 41: `.product(name: "Set Primitives", package: "swift-set-primitives"),` -- should use specific variant(s) of `Set_Primitives`
- Line 42: `.product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),` -- should use specific variant(s) of `Hash_Table_Primitives`
- Line 43: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 45: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`
- Line 56: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 67: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 76: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Dictionary Primitives Core/Dictionary.Ordered.Small.swift`: `import Index_Primitives` (line 14)
- `Sources/Dictionary Primitives Core/Dictionary.Ordered.Small.swift`: `import Set_Primitives` (line 15)
- `Sources/Dictionary Primitives Core/Dictionary.Ordered.Static.swift`: `import Hash_Table_Primitives` (line 13)

### swift-dimension-primitives

**Package.swift violations:**
- Line 34: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 35: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 36: `.product(name: "Numeric Primitives", package: "swift-numeric-primitives"),` -- should use specific variant(s) of `Numeric_Primitives`

**Source file violations:**
- `Sources/Dimension Primitives/Axis+CaseIterable.swift`: `import Ordinal_Primitives` (line 6)
- `Sources/Dimension Primitives/Tagged+Dimension.swift`: `import Tagged_Primitives` (line 14)
- `Sources/Dimension Primitives/Tagged+Quantized.swift`: `import Numeric_Primitives` (line 4)

### swift-endian-primitives

**Package.swift violations:**
- Line 28: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 29: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`

### swift-equation-primitives

**Package.swift violations:**
- Line 36: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-finite-primitives

**Package.swift violations:**
- Line 39: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 40: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 41: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 42: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 50: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`

**Source file violations:**
- `Sources/Finite Primitives Core/Finite.Enumerable.swift`: `import Ordinal_Primitives` (line 4)
- `Sources/Finite Primitives Core/Finite.Enumeration.swift`: `import Ordinal_Primitives` (line 4)
- `Sources/Finite Primitives Core/Finite.Enumeration.swift`: `import Index_Primitives` (line 5)
- `Sources/Finite Primitives Core/Index.Bounded.swift`: `import Index_Primitives` (line 4)
- `Sources/Finite Primitives Core/Index.Bounded.swift`: `import Ordinal_Primitives` (line 5)
- `Sources/Finite Primitives Core/Index.Bounded.swift`: `import Tagged_Primitives` (line 6)
- `Sources/Finite Primitives Core/Ordinal.Finite.swift`: `import Ordinal_Primitives` (line 4)
- `Sources/Finite Primitives Core/Ordinal.Finite.swift`: `import Tagged_Primitives` (line 5)
- `Sources/Finite Primitives Core/Tagged+Finite.Enumerable.swift`: `import Ordinal_Primitives` (line 4)
- `Sources/Finite Primitives Core/Tagged+Finite.Enumerable.swift`: `import Tagged_Primitives` (line 5)
- `Sources/Finite Primitives Core/Tagged+Ordinal.Finite.swift`: `import Ordinal_Primitives` (line 4)
- `Sources/Finite Primitives Core/Tagged+Ordinal.Finite.swift`: `import Tagged_Primitives` (line 5)

### swift-formatting-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-geometry-primitives

**Package.swift violations:**
- Line 38: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 40: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

**Source file violations:**
- `Sources/Geometry Primitives/Geometry.Arc.swift`: `import Affine_Primitives` (line 4)
- `Sources/Geometry Primitives/Geometry.Ball.swift`: `import Affine_Primitives` (line 4)
- `Sources/Geometry Primitives/Geometry.Ellipse.swift`: `import Affine_Primitives` (line 4)
- `Sources/Geometry Primitives/Geometry.Line.swift`: `import Affine_Primitives` (line 4)
- `Sources/Geometry Primitives/Geometry.swift`: `import Dimension_Primitives` (line 44)

### swift-graph-primitives

**Package.swift violations:**
- Line 106: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 107: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 108: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`
- Line 119: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 120: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 127: `.product(name: "Queue Primitives", package: "swift-queue-primitives"),` -- should use specific variant(s) of `Queue_Primitives`
- Line 128: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 129: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 137: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 148: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 149: `.product(name: "Set Primitives", package: "swift-set-primitives"),` -- should use specific variant(s) of `Set_Primitives`
- Line 158: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 159: `.product(name: "Set Primitives", package: "swift-set-primitives"),` -- should use specific variant(s) of `Set_Primitives`
- Line 167: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 182: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 192: `.product(name: "Queue Primitives", package: "swift-queue-primitives"),` -- should use specific variant(s) of `Queue_Primitives`
- Line 193: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 200: `.product(name: "Queue Primitives", package: "swift-queue-primitives"),` -- should use specific variant(s) of `Queue_Primitives`
- Line 201: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 208: `.product(name: "Heap Primitives", package: "swift-heap-primitives"),` -- should use specific variant(s) of `Heap_Primitives`
- Line 209: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 225: `.product(name: "Set Primitives", package: "swift-set-primitives"),` -- should use specific variant(s) of `Set_Primitives`
- Line 243: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 244: `.product(name: "Set Primitives", package: "swift-set-primitives"),` -- should use specific variant(s) of `Set_Primitives`

**Source file violations:**
- `Sources/Graph Topological Primitives/Graph.Traversal.Topological.swift`: `import Bit_Vector_Primitives` (line 3)

### swift-handle-primitives

**Package.swift violations:**
- Line 36: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 37: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 38: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`

### swift-hash-primitives

**Package.swift violations:**
- Line 44: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-hash-table-primitives

**Package.swift violations:**
- Line 44: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 46: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 47: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 48: `.product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),` -- should use specific variant(s) of `Cyclic_Index_Primitives`
- Line 49: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 59: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Hash Table Primitives Core/Hash.Occupied.Static.Iterator.swift`: `import Cardinal_Primitives` (line 12)
- `Sources/Hash Table Primitives Core/Hash.Occupied.View.Iterator.swift`: `import Cardinal_Primitives` (line 12)

### swift-heap-primitives

**Package.swift violations:**
- Line 72: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 85: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 94: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 103: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 112: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 133: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

### swift-index-primitives

**Package.swift violations:**
- Line 42: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 43: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 44: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 46: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-infinite-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`

### swift-input-primitives

**Package.swift violations:**
- Line 42: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 43: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`

### swift-kernel-primitives

**Package.swift violations:**
- Line 146: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`
- Line 152: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 153: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 154: `.product(name: "Time Primitives", package: "swift-time-primitives"),` -- should use specific variant(s) of `Time_Primitives`

### swift-layout-primitives

**Package.swift violations:**
- Line 30: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 32: `.product(name: "Geometry Primitives", package: "swift-geometry-primitives"),` -- should use specific variant(s) of `Geometry_Primitives`

### swift-lexer-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Token Primitives", package: "swift-token-primitives"),` -- should use specific variant(s) of `Token_Primitives`

### swift-link-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 33: `.product(name: "Vector Primitives", package: "swift-vector-primitives"),` -- should use specific variant(s) of `Vector_Primitives`

**Source file violations:**
- `Sources/Link Primitives/Link+Topology.swift`: `import Index_Primitives` (line 12)
- `Sources/Link Primitives/Link+Topology.swift`: `import Vector_Primitives` (line 13)
- `Sources/Link Primitives/Link.Header.swift`: `import Index_Primitives` (line 12)
- `Sources/Link Primitives/Link.Node.swift`: `import Vector_Primitives` (line 12)
- `Sources/Link Primitives/Link.Node.swift`: `import Index_Primitives` (line 13)

### swift-linux-primitives

**Package.swift violations:**
- Line 68: `.product(name: "Kernel Primitives", package: "swift-kernel-primitives")` -- should use specific variant(s) of `Kernel_Primitives`

### swift-list-primitives

**Package.swift violations:**
- Line 46: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 47: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`

### swift-machine-primitives

**Package.swift violations:**
- Line 184: `.product(name: "Graph Primitives", package: "swift-graph-primitives"),` -- should use specific variant(s) of `Graph_Primitives`

### swift-matrix-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Vector Primitives", package: "swift-vector-primitives"),` -- should use specific variant(s) of `Vector_Primitives`
- Line 32: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 33: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`

### swift-memory-primitives

**Package.swift violations:**
- Line 71: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 72: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 73: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 74: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 76: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 77: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 96: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`

**Source file violations:**
- `Sources/Memory Primitives Core/Memory.Address.swift`: `import Cardinal_Primitives` (line 13)
- `Sources/Memory Primitives Core/Memory.Address.swift`: `import Affine_Primitives` (line 14)

### swift-module-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Source Primitives", package: "swift-source-primitives")` -- should use specific variant(s) of `Source_Primitives`

### swift-network-primitives

**Package.swift violations:**
- Line 30: `.product(name: "Binary Primitives", package: "swift-binary-primitives"),` -- should use specific variant(s) of `Binary_Primitives`
- Line 32: `.product(name: "Kernel Primitives", package: "swift-kernel-primitives"),` -- should use specific variant(s) of `Kernel_Primitives`

### swift-numeric-primitives

**Package.swift violations:**
- Line 38: `.product(name: "Identity Primitives", package: "swift-tagged-primitives")` -- should use specific variant(s) of `Tagged_Primitives`

### swift-ordinal-primitives

**Package.swift violations:**
- Line 37: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 38: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`

### swift-parser-machine-primitives

**Package.swift violations:**
- Line 57: `.product(name: "Parser Primitives", package: "swift-parser-primitives"),` -- should use specific variant(s) of `Parser_Primitives`
- Line 58: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 59: `.product(name: "Machine Primitives", package: "swift-machine-primitives"),` -- should use specific variant(s) of `Machine_Primitives`
- Line 61: `.product(name: "Slab Primitives", package: "swift-slab-primitives"),` -- should use specific variant(s) of `Slab_Primitives`

**Source file violations:**
- `Sources/Parser Machine Combinator Primitives/Parser.Machine.Combinators.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Combinator Primitives/Parser.Machine.Recursive.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Failure.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Frame.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Leaf.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Node.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Program.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Run.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Core Primitives/Parser.Machine.Runtime.swift`: `import Parser_Primitives` (line 1)
- `Sources/Parser Machine Memoization Primitives/Parser.Machine.Run.Memoization.swift`: `import Parser_Primitives` (line 8)

### swift-parser-primitives

**Package.swift violations:**
- Line 178: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`
- Line 179: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`
- Line 189: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`
- Line 190: `.product(name: "Text Primitives", package: "swift-text-primitives"),` -- should use specific variant(s) of `Text_Primitives`
- Line 509: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`

**Source file violations:**
- `Sources/Parser Error Primitives/Parser.Either.swift`: `import Algebra_Primitives` (line 8)
- `Sources/Parser Literal Primitives/Parser.Literal.swift`: `import Array_Primitives` (line 8)

### swift-path-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-pool-primitives

**Package.swift violations:**
- Line 49: `.product(name: "Async Primitives", package: "swift-async-primitives"),` -- should use specific variant(s) of `Async_Primitives`
- Line 50: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 62: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`

### swift-queue-primitives

**Package.swift violations:**
- Line 47: `.product(name: "Buffer Primitives", package: "swift-buffer-primitives"),` -- should use specific variant(s) of `Buffer_Primitives`
- Line 48: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 49: `.product(name: "Vector Primitives", package: "swift-vector-primitives"),` -- should use specific variant(s) of `Vector_Primitives`
- Line 50: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`
- Line 52: `.product(name: "List Primitives", package: "swift-list-primitives"),` -- should use specific variant(s) of `List_Primitives`

**Source file violations:**
- `Sources/Queue Primitives Core/Queue.swift`: `import List_Primitives` (line 14)
- `Sources/Queue Primitives Core/Queue.swift`: `import Vector_Primitives` (line 16)

### swift-range-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Vector Primitives", package: "swift-vector-primitives"),` -- should use specific variant(s) of `Vector_Primitives`

### swift-region-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 30: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`

**Source file violations:**
- `Sources/Region Primitives/Cardinal.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Clock.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Corner.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Edge.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Octant.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Quadrant.swift`: `import Algebra_Primitives` (line 4)
- `Sources/Region Primitives/Sextant.swift`: `import Algebra_Primitives` (line 4)

### swift-scalar-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-sequence-primitives

**Package.swift violations:**
- Line 43: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`

### swift-set-primitives

**Package.swift violations:**
- Line 47: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 48: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 50: `.product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),` -- should use specific variant(s) of `Hash_Table_Primitives`
- Line 51: `.product(name: "Storage Primitives", package: "swift-storage-primitives"),` -- should use specific variant(s) of `Storage_Primitives`
- Line 52: `.product(name: "Buffer Primitives", package: "swift-buffer-primitives"),` -- should use specific variant(s) of `Buffer_Primitives`
- Line 53: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`
- Line 62: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`
- Line 63: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 64: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 66: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`

**Source file violations:**
- `Sources/Set Ordered Primitives/Set.Ordered Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered ~Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered ~Copyable.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered+Sequence.Consume.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered+Sequence.Consume.swift`: `import Index_Primitives` (line 14)
- `Sources/Set Ordered Primitives/Set.Ordered+Sequence.Drain.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Algebra.Symmetric.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Algebra.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Consume.swift`: `import Index_Primitives` (line 14)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed+Sequence.Drain.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift`: `import Ordinal_Primitives` (line 14)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Fixed.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Indexed.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Indexed.swift`: `import Ordinal_Primitives` (line 14)
- `Sources/Set Ordered Primitives/Set.Ordered.Indexed.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Iterator.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Iterator.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Small Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Small Copyable.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Small+Sequence.Consume.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Small+Sequence.Consume.swift`: `import Index_Primitives` (line 14)
- `Sources/Set Ordered Primitives/Set.Ordered.Small+Sequence.Drain.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Small.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Static Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Static Copyable.swift`: `import Cardinal_Primitives` (line 15)
- `Sources/Set Ordered Primitives/Set.Ordered.Static+Sequence.Consume.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Static+Sequence.Drain.swift`: `import Sequence_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Static.swift`: `import Index_Primitives` (line 13)
- `Sources/Set Ordered Primitives/Set.Ordered.Static.swift`: `import Finite_Primitives` (line 14)
- `Sources/Set Primitives Core/Set.Ordered.Error.swift`: `import Index_Primitives` (line 12)
- `Sources/Set Primitives Core/Set.Ordered.Small.swift`: `import Hash_Table_Primitives` (line 13)
- `Sources/Set Primitives Core/Set.Ordered.Static.swift`: `import Hash_Table_Primitives` (line 13)

### swift-slab-primitives

**Package.swift violations:**
- Line 54: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 55: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 56: `.product(name: "Bit Primitives", package: "swift-bit-primitives"),` -- should use specific variant(s) of `Bit_Primitives`
- Line 70: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 80: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

**Source file violations:**
- `Sources/Slab Dynamic Primitives/Slab Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Slab Dynamic Primitives/Slab Copyable.swift`: `import Bit_Primitives` (line 14)
- `Sources/Slab Dynamic Primitives/Slab.Indexed Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Slab Primitives Core/Slab ~Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Slab Primitives Core/Slab ~Copyable.swift`: `import Bit_Primitives` (line 14)
- `Sources/Slab Primitives Core/Slab.Indexed ~Copyable.swift`: `import Index_Primitives` (line 13)
- `Sources/Slab Primitives Core/Slab.Indexed ~Copyable.swift`: `import Bit_Primitives` (line 14)
- `Sources/Slab Primitives Core/Slab.Static ~Copyable.swift`: `import Index_Primitives` (line 14)
- `Sources/Slab Primitives Core/Slab.Static ~Copyable.swift`: `import Finite_Primitives` (line 15)
- `Sources/Slab Primitives Core/Slab.Static ~Copyable.swift`: `import Bit_Primitives` (line 16)
- `Sources/Slab Primitives Core/Slab.swift`: `import Index_Primitives` (line 14)
- `Sources/Slab Primitives Core/Slab.swift`: `import Bit_Primitives` (line 15)
- `Sources/Slab Static Primitives/Slab.Static Copyable.swift`: `import Index_Primitives` (line 14)
- `Sources/Slab Static Primitives/Slab.Static Copyable.swift`: `import Bit_Primitives` (line 15)

### swift-source-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Text Primitives", package: "swift-text-primitives")` -- should use specific variant(s) of `Text_Primitives`

### swift-space-primitives

**Package.swift violations:**
- Line 29: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

### swift-stack-primitives

**Package.swift violations:**
- Line 58: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 72: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 82: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 93: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
- Line 94: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 105: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

### swift-state-primitives

**Package.swift violations:**
- Line 32: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-storage-primitives

**Package.swift violations:**
- Line 75: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 76: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`
- Line 77: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 78: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 98: `.product(name: "Vector Primitives", package: "swift-vector-primitives"),` -- should use specific variant(s) of `Vector_Primitives`
- Line 109: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 120: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 130: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 131: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 141: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 142: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 152: `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),` -- should use specific variant(s) of `Bit_Vector_Primitives`
- Line 161: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`

**Source file violations:**
- `Sources/Storage Primitives Core/Storage.swift`: `import Index_Primitives` (line 12)
- `Sources/Storage Primitives Core/Storage.swift`: `import Finite_Primitives` (line 14)
- `Sources/Storage Split Primitives/Storage.Split.swift`: `import Index_Primitives` (line 12)

### swift-string-primitives

**Package.swift violations:**
- Line 30: `.product(name: "Memory Primitives", package: "swift-memory-primitives"),` -- should use specific variant(s) of `Memory_Primitives`
- Line 31: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-structured-queries-primitives

**Package.swift violations:**
- Line 33: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`

### swift-symbol-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Text Primitives", package: "swift-text-primitives")` -- should use specific variant(s) of `Text_Primitives`

### swift-symmetry-primitives

**Package.swift violations:**
- Line 38: `.product(name: "Algebra Primitives", package: "swift-algebra-primitives"),` -- should use specific variant(s) of `Algebra_Primitives`
- Line 39: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`
- Line 41: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`
- Line 42: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`
- Line 43: `.product(name: "Finite Primitives", package: "swift-finite-primitives"),` -- should use specific variant(s) of `Finite_Primitives`
- Line 45: `.product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),` -- should use specific variant(s) of `Ordinal_Primitives`

### swift-syntax-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Token Primitives", package: "swift-token-primitives")` -- should use specific variant(s) of `Token_Primitives`

### swift-system-primitives

**Package.swift violations:**
- Line 27: `.product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),` -- should use specific variant(s) of `Cardinal_Primitives`

### swift-terminal-primitives

**Package.swift violations:**
- Line 42: `.product(name: "Kernel Primitives", package: "swift-kernel-primitives")` -- should use specific variant(s) of `Kernel_Primitives`
- Line 51: `.product(name: "Input Primitives", package: "swift-input-primitives"),` -- should use specific variant(s) of `Input_Primitives`

### swift-test-primitives

**Package.swift violations:**
- Line 47: `.product(name: "Identity Primitives", package: "swift-tagged-primitives"),` -- should use specific variant(s) of `Tagged_Primitives`
- Line 48: `.product(name: "Source Primitives", package: "swift-source-primitives"),` -- should use specific variant(s) of `Source_Primitives`
- Line 49: `.product(name: "Sample Primitives", package: "swift-sample-primitives"),` -- should use specific variant(s) of `Sample_Primitives`
- Line 51: `.product(name: "Time Primitives", package: "swift-time-primitives"),` -- should use specific variant(s) of `Time_Primitives`
- Line 60: `.product(name: "Async Primitives", package: "swift-async-primitives"),` -- should use specific variant(s) of `Async_Primitives`

**Source file violations:**
- `Sources/Test Primitives Core/Test.Benchmark.Complexity+evidence.swift`: `import Sample_Primitives` (line 8)
- `Sources/Test Primitives Core/Test.Benchmark.Complexity.Candidate.Fit.swift`: `import Sample_Primitives` (line 8)
- `Sources/Test Primitives Core/Test.Benchmark.Complexity.Exponent.swift`: `import Sample_Primitives` (line 8)
- `Sources/Test Primitives Core/Test.Benchmark.Measurement.swift`: `import Sample_Primitives` (line 8)
- `Sources/Test Primitives Core/Test.Benchmark.Trend+MannKendall.swift`: `import Sample_Primitives` (line 8)

### swift-text-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Affine Primitives", package: "swift-affine-primitives"),` -- should use specific variant(s) of `Affine_Primitives`

### swift-time-primitives

**Package.swift violations:**
- Line 53: `.product(name: "Dimension Primitives", package: "swift-dimension-primitives"),` -- should use specific variant(s) of `Dimension_Primitives`

### swift-token-primitives

**Package.swift violations:**
- Line 31: `.product(name: "Text Primitives", package: "swift-text-primitives")` -- should use specific variant(s) of `Text_Primitives`

### swift-tree-primitives

**Package.swift violations:**
- Line 66: `.product(name: "Queue Primitives", package: "swift-queue-primitives"),` -- should use specific variant(s) of `Queue_Primitives`
- Line 67: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 136: `.product(name: "Array Primitives", package: "swift-array-primitives"),` -- should use specific variant(s) of `Array_Primitives`

### swift-vector-primitives

**Package.swift violations:**
- Line 34: `.product(name: "Index Primitives", package: "swift-index-primitives"),` -- should use specific variant(s) of `Index_Primitives`
- Line 35: `.product(name: "Cyclic Primitives", package: "swift-cyclic-primitives"),` -- should use specific variant(s) of `Cyclic_Primitives`
- Line 37: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`

### swift-windows-primitives

**Package.swift violations:**
- Line 53: `.product(name: "Kernel Primitives", package: "swift-kernel-primitives"),` -- should use specific variant(s) of `Kernel_Primitives`
- Line 55: `.product(name: "Sequence Primitives", package: "swift-sequence-primitives"),` -- should use specific variant(s) of `Sequence_Primitives`
