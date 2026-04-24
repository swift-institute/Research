# Binary Buffer Primitives Architectural Review

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: DECISION
tier: 2
---
-->

## Context

During compilation fixes for `IO Completions` in swift-io, a series of cascading type changes propagated from `Buffer.Aligned` through `Buffer.Unbounded` and into downstream consumers. The effort required to maintain the `Binary_Buffer_Primitives` module — and the observation that its only consumer (IO Completions) uses none of its Binary-layer features — raised a fundamental question about whether this package should exist.

## Question

Should `swift-binary-buffer-primitives` exist as a package? If so, is `Buffer.Aligned` correctly placed within it? If not, where should the aligned byte allocation primitive live?

## Inventory

### What Binary_Buffer_Primitives contains

| File | Responsibility | Depends on Binary? |
|------|---------------|--------------------|
| `Buffer.Aligned.swift` | Platform-specific aligned allocation (`posix_memalign` / `_aligned_malloc`), lifetime management (deinit frees), Span access, `Memory.Contiguous.Protocol` conformance | **No** — imports `Binary_Primitives` but uses only `Memory_Primitives` and `Buffer_Primitives` types |
| `Buffer.Aligned.Error.swift` | Error enum (allocationFailed) | **No** |
| `Buffer.Aligned+Convenience.swift` | Single-byte subscript, copy, zero | **No** |
| `Buffer.Aligned+Subscript.swift` | Range subscripts returning `Span<UInt8>` | **No** |
| `Buffer.Aligned+Binary.swift` | `Binary.Position`-typed accessors (`buffer.byte.at(position)`, `buffer[position]`), closure-based range access with `Binary.Error` | **Yes** — this is the only file that uses Binary types |
| `Buffer.Memory.swift` | `Memory.pageSize`, `Memory.pageAlignment`, `Memory.granularity` | **No** — uses platform C libs and `Memory_Primitives` |
| `Buffer.Unbounded.swift` | Resizable buffer backed by `Buffer.Aligned`, growth policies | **No** |
| `exports.swift` | Empty (commented out) | N/A |

**Result**: 1 of 7 substantive files (14%) uses Binary types. The other 86% is pure allocation/memory infrastructure.

### Who consumes Binary_Buffer_Primitives

| Consumer | Location | What it uses |
|----------|----------|-------------|
| IO Completions (7 files) | `swift-io/Sources/IO Completions/` | `Buffer<UInt8>.Aligned` type, `.count`, `withUnsafeBytes`/`withUnsafeMutableBytes` |

**What IO Completions does NOT use**:
- `Binary.Position` — never referenced
- `Binary.Cursor` — never referenced
- `Binary.Error` — never referenced
- `buffer.byte` accessor — never referenced
- Any range access via `withBytes(in:)` — never referenced

IO Completions uses `Buffer.Aligned` as a **dumb byte slab**: allocate, store, extract address+count for kernel APIs, return to caller.

### Namespace issue

`Buffer.Aligned` is defined as:

```swift
extension Buffer {         // Buffer<Element: ~Copyable>
    public struct Aligned: ~Copyable, @unchecked Sendable { ... }
}
```

This means `Buffer<String>.Aligned`, `Buffer<Int>.Aligned`, `Buffer<MyType>.Aligned` all compile — and all produce identical UInt8 byte buffers. The `Element` generic parameter is **meaningless** for `Aligned`. Consumers write `Buffer<UInt8>.Aligned` by convention, but the compiler does not enforce this.

## Analysis

### Option A: Keep Binary_Buffer_Primitives as-is

**Description**: No change. `Buffer.Aligned` stays in the binary-buffer bridge package.

**Advantages**:
- No migration work
- Currently compiles

**Disadvantages**:
- 86% of the package has nothing to do with Binary
- Only consumer uses 0% of the Binary features
- Forces tier 16 dependency (binary + buffer + index) for code that only needs aligned allocation
- `Buffer<Element>.Aligned` namespace pollution (Element is meaningless)
- The package name promises "Binary Buffer" but delivers "Aligned Allocation + one optional extension"

### Option B: Move Buffer.Aligned to Buffer_Primitives

**Description**: Move `Buffer.Aligned`, `Buffer.Aligned.Error`, `+Convenience`, `+Subscript`, `Buffer.Unbounded`, and `Buffer.Memory` into `swift-buffer-primitives`. Leave only `+Binary.swift` in `swift-binary-buffer-primitives` as a genuine bridge module.

**Advantages**:
- Buffer.Aligned is available at tier 15 (buffer-primitives) instead of tier 16
- IO Completions can drop the Binary_Buffer_Primitives dependency entirely
- The bridge package becomes honest: it only contains the Binary.Position extensions
- Separation of concerns: allocation is storage, position-typing is binary

**Disadvantages**:
- `Buffer<Element>.Aligned` namespace issue persists (Element still meaningless)
- Buffer.Aligned sits alongside element-generic containers (Ring, Linear, Slab...) which may confuse

**Namespace sub-option**: Constrain `Buffer.Aligned` to `where Element == UInt8` so only `Buffer<UInt8>.Aligned` compiles. This makes the generic parameter meaningful and prevents `Buffer<String>.Aligned`.

### Option C: Move aligned allocation to Memory_Primitives

**Description**: `Buffer.Aligned` is fundamentally an aligned memory allocator. Move it to `swift-memory-primitives` as `Memory.Aligned` (or `Memory.Buffer.Aligned`).

**Advantages**:
- Available at a lower tier (memory-primitives is tier ~6)
- Semantically accurate: this is memory allocation, not a data structure
- `Memory.Alignment` (its key dependency) is already in memory-primitives
- `Memory.Contiguous.Protocol` (its conformance) is already in memory-primitives
- Cleanest dependency graph: no need for buffer-primitives or binary-primitives

**Disadvantages**:
- `Memory.Aligned` loses the `Buffer` namespace
- Memory_Primitives is currently about memory semantics (alignment, contiguity, addresses), not allocation. Adding allocation changes its scope.
- May need `Buffer.Memory.pageSize` to also move (or it already has Memory.pageSize?)

**Naming considerations**: `Memory.Aligned` or `Memory.Buffer` or `Memory.Allocation.Aligned` — needs naming research.

### Option D: Dedicated package (swift-aligned-allocation-primitives or similar)

**Description**: Create a focused package for platform-specific aligned allocation.

**Advantages**:
- Single responsibility
- Minimal dependency set (only memory-primitives + platform C)
- Available at a low tier

**Disadvantages**:
- One more package to maintain
- Small package (5 files)
- May be over-modularization

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Dependency honesty** | High | Does importing this module give you what its name promises? |
| **Tier minimality** | High | Is the type available at the lowest tier that makes sense? |
| **Namespace correctness** | High | Does the generic parameter (if any) make sense? |
| **Consumer impact** | Medium | How many consumers need to change imports? |
| **Separation of concerns** | High | Is allocation separated from position-typing? |

## Comparison

| Criterion | A (keep) | B (buffer-prims) | C (memory-prims) | D (dedicated) |
|-----------|----------|-------------------|-------------------|---------------|
| Dependency honesty | Poor — name says "Binary Buffer", 86% is allocation | Good — allocation in buffer package | Best — allocation in memory package | Good — dedicated package |
| Tier minimality | Poor — tier 16 for allocation | Better — tier 15 | Best — tier ~6 | Best — very low tier |
| Namespace correctness | Poor — `Element` meaningless | Needs `where Element == UInt8` | Good — `Memory.Aligned` | Good |
| Consumer impact | None | Low — 7 files change import | Low — 7 files change import + type name | Low — same |
| Separation of concerns | Poor — allocation mixed with binary | Good — allocation separate, bridge module honest | Best — pure allocation | Good |

## Constraints

1. `Buffer.Aligned` is `~Copyable` and uses `posix_memalign` / `_aligned_malloc` — platform-specific C
2. It conforms to `Memory.Contiguous.Protocol` — which is in memory-primitives
3. `Buffer.Unbounded` depends on `Buffer.Growth.Policy` — which is in buffer-primitives
4. The `Binary.Position` extensions (`+Binary.swift`) genuinely need both binary-primitives and the aligned buffer type
5. IO Completions is the only consumer — migration cost is bounded

## Preliminary Assessment

**Option A (keep) is the weakest**: The package name promises binary-buffer integration, but 86% of its code and 100% of actual consumer usage is pure allocation infrastructure. This is a naming lie.

**Option C (memory-primitives) has the cleanest semantics** but may expand memory-primitives' scope beyond its current focus. Needs further investigation.

**Option B (buffer-primitives) is the pragmatic middle ground**: Move allocation to buffer-primitives, constrain to `where Element == UInt8`, and let binary-buffer-primitives become the thin bridge it should be.

**The `Buffer<Element>.Aligned` namespace issue is independent but urgent**: Regardless of which option is chosen, the unconstrained generic parameter should be fixed. `Buffer<String>.Aligned` should not compile.

## Outcome

**Status**: DECISION — Option B selected and implemented (2026-02-24)

**Decision**: Move `Buffer.Aligned` and `Buffer.Unbounded` to `swift-buffer-primitives` with `where Element == UInt8` constraint. Delete `swift-binary-buffer-primitives`.

**Key implementation choices**:

1. **Option B (buffer-primitives)** selected as the pragmatic middle ground
2. `Buffer.Aligned` constrained to `extension Buffer where Element == UInt8` — `Buffer<String>.Aligned` no longer compiles
3. **Pure Swift allocation** — replaced `posix_memalign`/`_aligned_malloc` with `UnsafeMutableRawPointer.allocate(byteCount:alignment:)`, eliminating all platform C imports
4. **Empty buffer simplification** — removed `emptyBufferSentinel` global; empty buffers allocate 1 byte with requested alignment
5. `Buffer.Unbounded` moved alongside `Buffer.Aligned` (uses `Growth.Policy` already in buffer-primitives)
6. `pageAligned` factory removed — requires platform-specific `pageSize` query; zero external callers
7. `Memory.pageSize`/`pageAlignment`/`granularity` removed — zero callers outside deleted package
8. `Buffer.Aligned+Binary.swift` not migrated — `Binary.Position` accessors were speculative with zero callers
9. `invalidSize` error case removed — `Cardinal` cannot be negative
10. IO Completions (sole consumer) already used `Buffer<UInt8>.Aligned` — only import removal needed

## References

- `swift-binary-buffer-primitives/Sources/Binary Buffer Primitives/` — all 8 source files
- `swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.swift` — `enum Buffer<Element: ~Copyable>`
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Alignment.swift` — alignment type
- `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Contiguous.Protocol.swift` — conformance protocol
- `swift-io/Sources/IO Completions/` — sole consumer (7 files)
- `Documentation.docc/Primitives Tiers.md` — tier 14 (binary), 15 (buffer), 16 (binary-buffer)
