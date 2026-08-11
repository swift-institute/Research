# Kernel.File and Kernel.Memory Type Placement

<!--
---
version: 1.1.0
last_updated: 2026-02-28
status: DECISION
---
-->

## Context

After maximizing modularization of kernel-primitives, Core was reduced from 49 to 6 files:

| File | Type | Role |
|------|------|------|
| `Kernel.swift` | `enum Kernel` | Root namespace |
| `Kernel.File.swift` | `enum File`, `enum Space` | File namespace + phantom tag |
| `Kernel.File.Offset.swift` | `Coordinate.X<Space>.Value<Int64>` | File position |
| `Kernel.File.Size.swift` | `Magnitude<Space>.Value<Int64>` | File byte magnitude |
| `Kernel.Memory.swift` | `enum Memory` | Memory namespace |
| `exports.swift` | Re-exports | Dependency funnel |

This research investigates:
1. Whether these types are correctly placed in kernel-primitives, or should move upstream
2. Whether Dimension Primitives (`Coordinate`/`Magnitude`/`Displacement`) is still the right abstraction, vs. Ordinal/Cardinal/Vector from newer packages

## Question

Should `Kernel.File.Offset`, `Kernel.File.Size`, and `Kernel.File.Delta` continue to use Dimension Primitives, or should they be refactored to use the Ordinal/Cardinal/Affine.Discrete.Vector system?

## Analysis

### Option A: Keep Dimension Primitives (Current Design)

Current definitions:
```swift
// Kernel.File.Offset.swift
public typealias Offset = Coordinate.X<Space>.Value<Int64>
public typealias Delta = Displacement.X<Space>.Value<Int64>

// Kernel.File.Size.swift
public typealias Size = Magnitude<Space>.Value<Int64>
```

**How it works**: Dimension Primitives provides a category-theoretic affine geometry system:
- `Coordinate.X<Space>.Value<T>` = `Tagged<Coordinate.X<Space>, T>` — absolute position
- `Displacement.X<Space>.Value<T>` = `Tagged<Displacement.X<Space>, T>` — signed offset
- `Magnitude<Space>.Value<T>` = `Tagged<Measure<1, Space>, T>` — non-directional magnitude

Arithmetic rules enforced at compile time:
- `Coordinate - Coordinate → Displacement` (position difference)
- `Coordinate ± Displacement → Coordinate` (translate position)
- `Coordinate + Magnitude → Coordinate` (translate by unsigned amount)
- `Magnitude ± Magnitude → Magnitude` (combine sizes)

**Advantages**:
- Correctly models signed 64-bit file positions (`Int64` scalar)
- Enforces affine semantics: cannot add two file offsets (meaningless)
- `Magnitude` is naturally non-negative, matching file size semantics
- Well-established: Dimension Primitives is used by 18 packages across geometry, layout, color, and kernel
- `Space` phantom tag prevents mixing file coordinates with geometry coordinates

**Disadvantages**:
- Dimension Primitives carries significant geometry infrastructure (multi-axis coordinates, areas, volumes, cross products, quantization) that is unused by kernel
- The `X` in `Coordinate.X<Space>` implies spatial dimensionality (X/Y/Z axes) — file offsets are 1D positions, not spatial coordinates
- Custom `Offset + Size` arithmetic operators (lines 169-190 of `Kernel.File.Size.swift`) are hand-rolled rather than provided by the dimension system, indicating a mismatch
- `Magnitude<Space>` resolves to `Tagged<Measure<1, Space>, Int64>` — the `Measure<1, _>` intermediate is geometric notation leaking into file I/O

### Option B: Use Ordinal/Cardinal/Vector System

Hypothetical definitions:
```swift
public typealias Offset = Tagged<Space, Ordinal>        // Position
public typealias Delta = Tagged<Space, Affine.Discrete.Vector>  // Displacement
public typealias Size = Tagged<Space, Cardinal>          // Magnitude
```

**Fatal flaw**: Ordinal and Cardinal are `UInt`-based. File offsets are `Int64`:
- `lseek(fd, -100, SEEK_END)` requires negative offsets
- `off_t` is `int64_t` on all modern platforms
- File sizes can exceed `UInt` on 32-bit platforms (files > 4GB)

**Not viable** without fundamental changes to the Ordinal/Cardinal type system.

### Option C: Affine.Discrete.Vector Only

Hypothetical:
```swift
public typealias Offset = Tagged<Space, Affine.Discrete.Vector>  // Int-based, signed
```

**Flaw**: `Affine.Discrete.Vector` is semantically a displacement (the difference between two positions), not a position itself. A file offset is an absolute position. Using a displacement type for positions violates the affine space model.

Additionally, `Affine.Discrete.Vector` uses `Int` (platform word size), not `Int64`. On 32-bit platforms, this limits file offsets to 2GB.

### Option D: Raw Tagged<Space, Int64>

Hypothetical:
```swift
public typealias Offset = Tagged<Space, Int64>
public typealias Delta = Tagged<Delta, Int64>  // needs distinct phantom tag
public typealias Size = Tagged<Size, Int64>    // needs distinct phantom tag
```

**Advantages**:
- Eliminates Dimension Primitives dependency from Core
- Simple, no geometric baggage
- Uses `Int64` natively

**Disadvantages**:
- Loses all compile-time arithmetic safety:
  - `Offset + Offset` would compile (meaningless)
  - `Size - Size` could go negative (meaningless for magnitudes)
  - No `Offset - Offset → Delta` enforcement
- Would need to reimplement all arithmetic operators manually, poorly replicating what Dimension already provides
- Three separate phantom tags needed vs. one `Space` tag with three role distinctions

### Comparison

| Criterion | A: Dimension | B: Ordinal/Cardinal | C: Vector | D: Raw Tagged |
|-----------|:---:|:---:|:---:|:---:|
| Int64 support | **Yes** | No (UInt) | No (Int) | **Yes** |
| Signed positions | **Yes** | No | Yes | **Yes** |
| Affine safety | **Yes** | Yes | No (wrong role) | No |
| Magnitude safety | **Yes** | Yes | No | No |
| Minimal deps | No | N/A | N/A | **Yes** |
| No geometric baggage | No | N/A | N/A | **Yes** |
| Compile-time arithmetic | **Yes** | N/A | N/A | No |
| 32-bit safe | **Yes** (Int64) | No (UInt) | No (Int) | **Yes** |

### Why Ordinal/Cardinal/Vector Cannot Replace Dimension Here

The Ordinal/Cardinal/Vector system was designed for **in-memory data structure indexing**:
- Positions are non-negative (`UInt` — you can't have a negative array index)
- Counts are non-negative (`UInt` — you can't have negative elements)
- Displacements fit in `Int` (platform word size is sufficient for in-memory distances)

File I/O has fundamentally different constraints:
- Positions are signed 64-bit (`off_t = int64_t` — SEEK_END with negative offset)
- Sizes are unsigned 64-bit but must exceed 32-bit range (files > 4GB)
- The scalar type must be `Int64`, not `UInt` or `Int`

These are not the same domain. Using Ordinal/Cardinal for file offsets would be like using array indices for GPS coordinates — the abstraction doesn't fit.

### The Kernel.Memory Namespace

`Kernel.Memory.swift` contains only `extension Kernel { public enum Memory: Sendable {} }`. It exists in Core so that Kernel Memory Primitives (which extends `Kernel.Memory` with Address, Allocation, Error) can find the namespace.

This could be moved to Kernel Memory Primitives. Core doesn't reference `Kernel.Memory` — only the satellite does. However, keeping it in Core is harmless (1 file, 4 lines of code) and follows the convention that namespace enums live alongside their first definitions.

### The Custom Offset + Size Operators

`Kernel.File.Size.swift` originally defined hand-rolled `+`, `-`, `+=`, `-=` operators for `Offset ± Size → Offset`.

Investigation revealed:
- Dimension's `Tagged+Arithmatic.swift` provides generic `@inlinable` operators for `Coordinate.X<Space>.Value<Scalar> ± Magnitude<Space>.Value<Scalar> → Coordinate.X<Space>.Value<Scalar>` where `Scalar: AdditiveArithmetic`. Since `Int64: AdditiveArithmetic`, these resolve correctly for kernel's types.
- Dimension originally did not provide cross-type compound assignment operators (`+=`, `-=`). This was identified as a systematic gap and resolved upstream.

**Result**: All four hand-rolled operators (`+`, `-`, `+=`, `-=`) removed. Dimension now provides both binary and compound assignment operators for all cross-type pairs (see `swift-dimension-primitives/Research/cross-type-compound-assignment-completeness.md`). Verified: clean build succeeds.

### The Kernel.Memory Namespace

`Kernel.Memory` MUST remain a separate `enum`, not a typealias to `Memory_Primitives_Core.Memory`. Investigation found:

- `Kernel.Memory` defines **13+ genuinely new types** not in memory-primitives: `Error`, `Lock`, `Map`, `Map.Region`, `Map.Protection`, `Map.Flags`, `Map.Advice`, `Map.Sync.Flags`, `Map.Error`, `Shared.Error`, etc.
- Only 4 types are wrappers of memory-primitives types: `Address` (`Tagged<Kernel, Memory.Address>`), `Displacement`, `Allocation.Granularity`, `Page.Size`
- A typealias to an upstream enum would prevent extending it with kernel-specific nested types
- The separate enum correctly serves as a kernel-domain companion namespace

## Outcome

**Status**: DECISION

### Keep Dimension Primitives (Option A)

The current design is correct. Dimension Primitives is the right abstraction because:

1. **Int64 scalar**: Dimension supports arbitrary scalar types. Ordinal/Cardinal are locked to `UInt`.
2. **Affine semantics**: Compile-time prevention of meaningless operations (adding two positions, negating a size).
3. **Phantom typing**: Single `Space` tag distinguishes positions, displacements, and magnitudes without three separate phantom types.
4. **Established**: Used by 18 packages. Well-tested arithmetic.

The geometric baggage (multi-axis, areas, quantization) is a compile-time cost only — none of it appears at runtime in kernel code. The `X` in `Coordinate.X` is slightly misleading for 1D file offsets, but this is a naming aesthetic, not a semantic problem.

### All hand-rolled Offset ± Size operators removed

All four hand-rolled operators (`+`, `-`, `+=`, `-=`) were redundant shadows of Dimension's generic operators. The `+=` and `-=` gap was identified as a systematic omission in Dimension and resolved upstream by adding 24 cross-type compound assignment operators (see `swift-dimension-primitives/Research/cross-type-compound-assignment-completeness.md`).

### Keep Kernel.Memory as separate enum in Core

`Kernel.Memory` cannot be a typealias — it has 13+ genuinely new kernel-specific types. The separate namespace enum is correct and follows the same pattern as `Kernel.File`.

### No changes to upstream packages needed

Memory-primitives does not need file-size types. The file byte-space is a kernel concern, not a memory-primitives concern. The layering is correct:
- `Memory_Primitives_Core` provides `Memory.Alignment` (used by `File.Size.alignedUp/Down`)
- `Dimension_Primitives` provides the affine type system (positions, magnitudes, displacements)
- `Kernel_Primitives_Core` combines them into file-specific typed aliases

## References

- Dimension Primitives: `/Users/coen/Developer/swift-primitives/swift-dimension-primitives/`
- Ordinal/Cardinal system: `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/`, `swift-cardinal-primitives/`
- Affine Primitives: `/Users/coen/Developer/swift-primitives/swift-affine-primitives/`
- Memory Primitives: `/Users/coen/Developer/swift-primitives/swift-memory-primitives/`
- Index research: `/Users/coen/Developer/swift-primitives/swift-index-primitives/Research/index-count-offset-as-tagged.md`
- Compound assignment completeness: `/Users/coen/Developer/swift-primitives/swift-dimension-primitives/Research/cross-type-compound-assignment-completeness.md`
