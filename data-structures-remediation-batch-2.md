# Remediation Plans: Batch 2 (HIGH)

Generated: 2026-04-03

---

## swift-slab-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations): `Index_Primitives`, `Finite_Primitives`, `Bit_Primitives`

**Package.swift violations (banned umbrella deps):**

| Line | Current dep | Target affected |
|------|------------|-----------------|
| 70 | `Sequence Primitives` | Slab Dynamic Primitives |
| 80 | `Sequence Primitives` | Slab Static Primitives |

**Source file violations (banned umbrella imports):**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Slab Dynamic Primitives/exports.swift` | `@_exported public import Sequence_Primitives` | Re-export for consumers: `Sequence.Drain`, `Sequence.Drain.Protocol` | `@_exported public import Sequence_Primitives_Core` |
| `Sources/Slab Static Primitives/exports.swift` | `@_exported public import Sequence_Primitives` | Re-export for consumers: `Sequence.Drain`, `Sequence.Drain.Protocol` | `@_exported public import Sequence_Primitives_Core` |

Note: `Slab.Indexed Copyable.swift` and `Slab.Static Copyable.swift` use `Sequence.Drain` and `Sequence.Drain.Protocol` via the re-exported `Sequence_Primitives` — no direct import statements to change in those files.

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `.product(name: "Sequence Primitives", package: "swift-sequence-primitives")` | `.product(name: "Sequence Primitives Core", package: "swift-sequence-primitives")` | Slab Dynamic Primitives |
| `.product(name: "Sequence Primitives", package: "swift-sequence-primitives")` | `.product(name: "Sequence Primitives Core", package: "swift-sequence-primitives")` | Slab Static Primitives |

### Rationale

Both targets use only `Sequence.Drain` (enum tag) and `Sequence.Drain.Protocol` — both defined in `Sequence Primitives Core`. No `Sequence.Difference`, `Sequence.Map`, or other higher-level sequence types are used.

---

## swift-storage-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations): `Index_Primitives`, `Finite_Primitives`, `Vector_Primitives`

**Package.swift violations (banned umbrella deps):**

| Line | Current dep | Target affected |
|------|------------|-----------------|
| 76 | `Memory Primitives` | Storage Primitives Core |
| 77 | `Bit Vector Primitives` | Storage Primitives Core |
| 130 | `Bit Vector Primitives` | Storage Pool Inline Primitives |
| 141 | `Bit Vector Primitives` | Storage Arena Inline Primitives |
| 152 | `Bit Vector Primitives` | Storage Slab Primitives |
| 161 | `Memory Primitives` | Storage Split Primitives |

**Source file violations (banned umbrella imports):**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Storage Primitives Core/exports.swift` | `@_exported public import Memory_Primitives` | Re-export: `Memory`, `Memory.Address`, `Memory.Alignment`, `Memory.Contiguous`, `Memory.Contiguous.Protocol`, `Memory.Inline`, `Memory.Shift`, `Memory.Allocation` | `@_exported public import Memory_Primitives_Core` |
| `Sources/Storage Primitives Core/Storage.swift` | `public import Bit_Vector_Primitives` | `Bit.Vector.Bounded`, `Bit.Vector.Static` | `public import Bit_Vector_Primitives_Core` + `public import Bit_Vector_Static_Primitives` + `public import Bit_Vector_Bounded_Primitives` |
| `Sources/Storage Split Primitives/exports.swift` | `@_exported public import Memory_Primitives` | Re-export: `Memory.Address.Count`, `Memory.Address.Offset`, `Memory.Alignment` | `@_exported public import Memory_Primitives_Core` |
| `Sources/Storage Inline Primitives/Storage.Inline.swift` | `public import Bit_Vector_Primitives` | `Bit.Vector.Static` | `public import Bit_Vector_Static_Primitives` |
| `Sources/Storage Inline Primitives/Storage.Inline ~Copyable.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` operations | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Inline Primitives/Storage.Inline+Initialize.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` mutation | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Inline Primitives/Storage.Inline+Deinitialize.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` operations | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Inline Primitives/Storage.Inline+Move.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` operations | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Pool Primitives/Storage.Pool Copyable.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector` operations | `internal import Bit_Vector_Primitives_Core` |
| `Sources/Storage Pool Primitives/Storage.Pool ~Copyable.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector` operations | `internal import Bit_Vector_Primitives_Core` |
| `Sources/Storage Pool Inline Primitives/Storage.Pool.Inline ~Copyable.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` operations | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Arena Inline Primitives/Storage.Arena.Inline ~Copyable.swift` | `internal import Bit_Vector_Primitives` | `Bit.Vector.Static` operations | `internal import Bit_Vector_Static_Primitives` |
| `Sources/Storage Slab Primitives/exports.swift` | `@_exported public import Bit_Vector_Primitives` | Re-export: `Bit.Vector.Bounded` for slab bitmap | `@_exported public import Bit_Vector_Bounded_Primitives` |

Note: Several source-level `Bit_Vector_Primitives` imports were not listed in the violations document (which only reported `Storage.swift` and `Storage.Split.swift`). These were discovered by grepping the full source tree.

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `.product(name: "Memory Primitives", package: "swift-memory-primitives")` | `.product(name: "Memory Primitives Core", package: "swift-memory-primitives")` | Storage Primitives Core |
| `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives")` | `.product(name: "Bit Vector Primitives Core", package: "swift-bit-vector-primitives")`, `.product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives")`, `.product(name: "Bit Vector Bounded Primitives", package: "swift-bit-vector-primitives")` | Storage Primitives Core |
| `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives")` | `.product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives")` | Storage Pool Inline Primitives |
| `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives")` | `.product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives")` | Storage Arena Inline Primitives |
| `.product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives")` | `.product(name: "Bit Vector Bounded Primitives", package: "swift-bit-vector-primitives")` | Storage Slab Primitives |
| `.product(name: "Memory Primitives", package: "swift-memory-primitives")` | `.product(name: "Memory Primitives Core", package: "swift-memory-primitives")` | Storage Split Primitives |

### Additional Package.swift deps needed (not currently listed as violations)

Storage Primitives Core currently gets `Memory.Arena` and `Memory.Pool` types transitively through `Memory Primitives Core` (which re-exports them). Verification required: if `Memory Primitives Core` does NOT include `Memory.Arena` and `Memory.Pool` (which live in `Memory Arena Primitives` and `Memory Pool Primitives`), then Storage Primitives Core additionally needs:

| Additional dep | Reason |
|---------------|--------|
| `Memory Arena Primitives` | `Storage.Arena` composes `Memory.Arena` |
| `Memory Pool Primitives` | `Storage.Pool` composes `Memory.Pool` |

Note: `Storage Pool Primitives` target already depends on `Memory Pool Primitives` and `Storage Arena Primitives` already depends on `Memory Arena Primitives` — these are correct. The Core target may or may not need these, depending on whether `Storage.Arena` and `Storage.Pool` type declarations in Core need the full types or only forward-declare them.

### Rationale

- `Memory Primitives Core` provides `Memory`, `Memory.Address`, `Memory.Alignment`, `Memory.Contiguous`, `Memory.Contiguous.Protocol`, `Memory.Inline`, `Memory.Shift`, `Memory.Allocation`.
- `Bit Vector Primitives Core` provides `Bit.Vector`, `Bit.Vector.Protocol`.
- `Bit Vector Static Primitives` provides `Bit.Vector.Static`.
- `Bit Vector Bounded Primitives` provides `Bit.Vector.Bounded`.
- No `Bit Vector Dynamic Primitives` or `Bit Vector Inline Primitives` types are used.

---

## swift-binary-parser-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations): `Index_Primitives`, `Input_Primitives`, `Tagged_Primitives`

**Package.swift violations (banned umbrella deps):**

| Line | Current dep | Target affected |
|------|------------|-----------------|
| 72 | `Binary Primitives` | Binary Parser Primitives Core |
| 73 | `Parser Primitives` | Binary Parser Primitives Core |
| 99 | `Machine Primitives` | Binary Machine Primitives |

**Source file violations (banned umbrella imports):**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Binary Parser Primitives Core/exports.swift` | `@_exported public import Binary_Primitives` | Re-export for consumers: `Binary`, `Binary.Bytes`, `Binary.Endianness`, `Binary.LEB128`, `Binary.Parse`, `Binary.Error`, `Binary.Cursor`, `Binary.Count`, `Binary.Position`, `Binary.Offset`, `Binary.Space`, `Binary.Mask`, `Binary.Pattern` | `@_exported public import Binary_Primitives_Core` |
| `Sources/Binary Parser Primitives Core/exports.swift` | `@_exported public import Parser_Primitives` | Re-export for consumers: `Parser`, `Parser.Protocol`, `Parser.Printer`, `Parser.Input`, `Parser.Builder`, `Parseable` | `@_exported public import Parser_Primitives_Core` |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.swift` | `public import Machine_Primitives` | `Machine.Value`, `Machine.Transform`, `Machine.Combine`, `Machine.Finalize`, `Machine.Next`, `Machine.Capture.Mode.Reference` | See consolidated list below |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Builder.swift` | `public import Machine_Primitives` | `Machine.Builder`, `Machine.Capture.Store`, `Machine.Capture.Mode.Reference` | See consolidated list below |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Build.swift` | `public import Machine_Primitives` | (types used through local typealiases) | See consolidated list below |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Combinators.swift` | `public import Machine_Primitives` | `Machine.Node`, `Machine.Value`, `Machine.Transform.Erased`, `Machine.Transform.Throwing`, `Machine.Combine.Erased`, `Machine.Finalize.Array` | See consolidated list below |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Error.swift` | `import Machine_Primitives` | (no direct Machine type usage — import may be vestigial) | Remove import or replace with targeted import if compilation requires it |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Error.swift` | `import Parser_Primitives` | `Parser.EndOfInput.Error` | `import Parser_EndOfInput_Primitives` |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Frame.swift` | `public import Machine_Primitives` | `Machine.Frame`, `Machine.Capture.Mode.Reference` | `public import Machine_Frame_Primitives` + `public import Machine_Primitives_Core` |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Instruction.swift` | `import Machine_Primitives` | (no direct Machine type usage — instruction is Binary-local) | Remove import (vestigial) |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Node.swift` | `public import Machine_Primitives` | `Machine.Node`, `Machine.Capture.Mode.Reference` | `public import Machine_Node_Primitives` + `public import Machine_Primitives_Core` |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Program.swift` | `public import Machine_Primitives` | `Machine.Program`, `Machine.Capture.Mode.Reference` | `public import Machine_Program_Primitives` + `public import Machine_Primitives_Core` |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Run.swift` | `public import Machine_Primitives` | `Machine.Value`, `Machine.Frame` (via typealiases) | See consolidated list below |
| `Sources/Binary Machine Primitives/Binary.Bytes.Machine.Run.swift` | `public import Parser_Primitives` | `Parser.Input.Protocol` | `public import Parser_Primitives_Core` |

### Consolidated Machine Primitives variants needed by Binary Machine Primitives

| Variant module | Types used |
|---------------|------------|
| Machine Primitives Core | `Machine`, `Machine.Capture`, `Machine.Capture.Mode.Reference` |
| Machine Value Primitives | `Machine.Value`, `Machine.Value.Handle`, `Machine.Value.Arena` |
| Machine Capture Primitives | `Machine.Capture.Store`, `Machine.Capture.Frozen` |
| Machine Transform Primitives | `Machine.Transform`, `Machine.Transform.Erased`, `Machine.Transform.Throwing` |
| Machine Combine Primitives | `Machine.Combine`, `Machine.Combine.Erased` |
| Machine Next Primitives | `Machine.Next`, `Machine.Next.Erased` |
| Machine Finalize Primitives | `Machine.Finalize`, `Machine.Finalize.Array` |
| Machine Frame Primitives | `Machine.Frame`, `Machine.Frame.Sequence` |
| Machine Node Primitives | `Machine.Node`, `Machine.Node.ID` |
| Machine Program Primitives | `Machine.Program`, `Machine.Builder` |

**10 of 11 variants needed** (only `Machine Convenience Primitives` is not required). The umbrella `Machine Primitives` also re-exports `Graph_Primitives` — verify whether any Graph types are used (likely not, since Machine provides its own `Machine.Node.ID` which wraps `Graph.Node`).

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `.product(name: "Binary Primitives", package: "swift-binary-primitives")` | `.product(name: "Binary Primitives Core", package: "swift-binary-primitives")` | Binary Parser Primitives Core |
| `.product(name: "Parser Primitives", package: "swift-parser-primitives")` | `.product(name: "Parser Primitives Core", package: "swift-parser-primitives")` | Binary Parser Primitives Core |
| `.product(name: "Machine Primitives", package: "swift-machine-primitives")` | `.product(name: "Machine Primitives Core", package: "swift-machine-primitives")`, `.product(name: "Machine Value Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Capture Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Transform Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Combine Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Next Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Finalize Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Frame Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Node Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Program Primitives", package: "swift-machine-primitives")` | Binary Machine Primitives |

### Additional notes

1. The `Binary Parser Primitives Core` target re-exports both `Binary_Primitives` and `Parser_Primitives` as umbrellas. The replacement with `Binary_Primitives_Core` and `Parser_Primitives_Core` covers the core types. If downstream consumers also need `Parser Error Primitives`, `Parser EndOfInput Primitives`, `Parser Match Primitives`, etc., those would need to be added as additional re-exports. The Binary Machine Primitives target itself needs `Parser EndOfInput Primitives` (for `Parser.EndOfInput.Error` in the error bridging code).

2. The `Binary Parser Primitives` umbrella target (line 153-166) re-exports all variant targets within this package — no change needed there, as it re-exports the specific variant targets, not the banned umbrella.

3. For `Binary Machine Primitives`, the `Machine_Primitives` import is pervasive (every file). Consider adding a `Machine_Primitives_Core` + targeted variant imports to each file, or having Binary Machine Primitives depend on a custom "Machine subset" re-export target if machine-primitives provides one.

### Rationale

- `Binary Primitives Core` provides all core Binary types (`Binary`, `Binary.Bytes`, `Binary.Endianness`, `Binary.LEB128`, `Binary.Parse`, `Binary.Error`, `Binary.Cursor`, etc.). The package does not need `Binary Format Primitives` or `Binary Serializable Primitives`.
- `Parser Primitives Core` provides `Parser`, `Parser.Protocol`, `Parser.Printer`, `Parser.Input`, `Parseable`. Additionally, `Parser EndOfInput Primitives` is needed for error bridging in `Binary.Bytes.Machine.Error.swift`.
- Binary Machine Primitives uses 10 of 11 Machine variant modules — nearly the full umbrella.

---

## swift-parser-machine-primitives

### True violations (after filtering canonical umbrellas)

Filtered out (canonical, not violations): `Tagged_Primitives`

**Package.swift violations (banned umbrella deps):**

| Line | Current dep | Target affected |
|------|------------|-----------------|
| 57 | `Parser Primitives` | Parser Machine Core Primitives |
| 59 | `Machine Primitives` | Parser Machine Core Primitives |
| 61 | `Slab Primitives` | Parser Machine Core Primitives |

**Source file violations (banned umbrella imports):**

| Source file | Current import | Used types | Replacement import |
|-------------|---------------|------------|-------------------|
| `Sources/Parser Machine Core Primitives/exports.swift` | `@_exported public import Parser_Primitives` | Re-export: `Parser`, `Parser.Protocol`, `Parser.Input`, `Parser.Input.Protocol` | `@_exported public import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/exports.swift` | `@_exported public import Machine_Primitives` | Re-export: all Machine types for downstream consumers | See consolidated list below |
| `Sources/Parser Machine Core Primitives/exports.swift` | `@_exported public import Slab_Primitives` | Re-export for downstream consumers (no Slab types directly used in source) | `@_exported public import Slab_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.swift` | `@_exported import Parser_Primitives` | `Parser` (namespace for extension), `Parser.Protocol`, `Parser.Input.Protocol`, `Machine.Value`, `Machine.Transform`, `Machine.Combine`, `Machine.Finalize`, `Machine.Next`, `Machine.Capture.Mode.Reference`, `Machine.Capture.Store`, `Machine.Builder` | `@_exported import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Failure.swift` | `import Parser_Primitives` | `Parser.Machine` (extension on own type) | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Frame.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Leaf.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Protocol`, `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Node.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Program.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Run.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Core Primitives/Parser.Machine.Runtime.swift` | `import Parser_Primitives` | `Parser.Machine` (extension) | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Combinator Primitives/Parser.Machine.Combinators.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Protocol`, `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Combinator Primitives/Parser.Machine.Recursive.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |
| `Sources/Parser Machine Memoization Primitives/Parser.Machine.Run.Memoization.swift` | `import Parser_Primitives` | `Parser.Machine` (extension), `Parser.Input.Protocol` | `import Parser_Primitives_Core` |

### Consolidated Machine Primitives variants needed

Same as binary-parser-primitives — the Parser Machine Core target uses the full Machine infrastructure:

| Variant module | Types used |
|---------------|------------|
| Machine Primitives Core | `Machine`, `Machine.Capture`, `Machine.Capture.Mode.Reference` |
| Machine Value Primitives | `Machine.Value`, `Machine.Value.Handle`, `Machine.Value.Arena` |
| Machine Capture Primitives | `Machine.Capture.Store`, `Machine.Capture.Frozen` |
| Machine Transform Primitives | `Machine.Transform`, `Machine.Transform.Erased`, `Machine.Transform.Throwing` |
| Machine Combine Primitives | `Machine.Combine`, `Machine.Combine.Erased` |
| Machine Next Primitives | `Machine.Next`, `Machine.Next.Erased` |
| Machine Finalize Primitives | `Machine.Finalize`, `Machine.Finalize.Array` |
| Machine Frame Primitives | `Machine.Frame`, `Machine.Frame.Sequence` |
| Machine Node Primitives | `Machine.Node`, `Machine.Node.ID` |
| Machine Program Primitives | `Machine.Program`, `Machine.Builder` |
| Machine Convenience Primitives | (verify — may be needed for builder carrier methods) |

### Package.swift changes

| Current product dep | Replacement | Target affected |
|--------------------|-------------|-----------------|
| `.product(name: "Parser Primitives", package: "swift-parser-primitives")` | `.product(name: "Parser Primitives Core", package: "swift-parser-primitives")` | Parser Machine Core Primitives |
| `.product(name: "Machine Primitives", package: "swift-machine-primitives")` | `.product(name: "Machine Primitives Core", package: "swift-machine-primitives")`, `.product(name: "Machine Value Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Capture Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Transform Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Combine Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Next Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Finalize Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Frame Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Node Primitives", package: "swift-machine-primitives")`, `.product(name: "Machine Program Primitives", package: "swift-machine-primitives")` | Parser Machine Core Primitives |
| `.product(name: "Slab Primitives", package: "swift-slab-primitives")` | `.product(name: "Slab Primitives Core", package: "swift-slab-primitives")` | Parser Machine Core Primitives |

### Additional notes

1. **Parser_Primitives re-export**: The Core exports.swift re-exports `Parser_Primitives` for downstream consumers. Only `Parser Primitives Core` types are needed (no Parser Error, EndOfInput, Match, etc. used directly). If downstream packages of parser-machine-primitives need those, they should import them directly.

2. **Slab_Primitives**: No `Slab` type is directly referenced in any parser-machine source file. The import and re-export appears to exist solely to provide `Slab_Primitives` to downstream consumers transitively. If downstream consumers need Slab types, they should depend on them directly. Consider removing this dependency entirely.

3. **Machine Primitives**: Like binary-parser, this package uses 10+ of 11 Machine variants. Both parser-machine and binary-parser are "machine client" packages that need essentially the full Machine API.

4. **`Stack_Primitives`** (line 60): Not flagged — `stack` is not in the banned umbrella list. However, note that `Stack_Primitives` is used in `Parser.Machine.Run.swift` and `Parser.Machine.Run.Memoization.swift` for the `Stack<Frame>` type.

### Rationale

- `Parser Primitives Core` is sufficient: parser-machine only extends `Parser` namespace, uses `Parser.Protocol`, and `Parser.Input.Protocol`.
- `Slab Primitives Core` is sufficient if re-export is retained; the dependency may be removable entirely.
- Machine Primitives: near-complete variant coverage required (same as binary-parser-primitives).

---

## Summary

| Package | Banned violations (source) | Banned violations (Package.swift) | Total true violations |
|---------|--:|--:|--:|
| swift-slab-primitives | 2 | 2 | 4 |
| swift-storage-primitives | 14 | 6 | 20 |
| swift-binary-parser-primitives | 12 | 3 | 15 |
| swift-parser-machine-primitives | 14 | 3 | 17 |
| **TOTAL** | **42** | **14** | **56** |

Note: swift-storage-primitives has more source violations than originally reported in umbrella-violations.md (which listed 3 source violations; actual count is 14 after including all `Bit_Vector_Primitives` and `Memory_Primitives` imports found by grepping the full source tree).
