# Memory Domain Cross-Package Inventory

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: DECISION
tier: 2
applies_to: [swift-memory-primitives, swift-kernel-primitives, swift-memory, swift-kernel, swift-iso-9945, swift-windows-primitives]
normative: false
---
-->

## Context

The Memory domain spans two packages across two architectural layers:

| Layer | Package | Namespace | Role |
|-------|---------|-----------|------|
| 1 (Primitives) | swift-memory-primitives | `Memory.*` | Atomic memory types: Address, Alignment, Buffer, Allocator, Arena, Pool |
| 1 (Primitives) | swift-kernel-primitives | `Kernel.Memory.*` | OS virtual memory interface: Map, Lock, Shared, Page |
| 2 (Standards) | swift-iso-9945 | `ISO_9945.Kernel.Memory.*` | POSIX syscall implementations (mmap, mlock, shm_open) |
| 1 (Primitives) | swift-windows-primitives | `Windows.Kernel.Memory.*` | Windows API implementations (VirtualAlloc, CreateFileMapping) |
| 3 (Foundations) | swift-kernel | `Kernel` | Umbrella re-export + `Kernel.System.Memory.total` |
| 3 (Foundations) | swift-memory | `Memory.*` | Policy layer: Memory.Map (~Copyable RAII), Lock.Token, Allocation tracking |

**Trigger**: Audit whether `Kernel.Memory` re-implements types that already exist in memory-primitives.

**Scope**: Ecosystem-wide per [RES-002a] — spans primitives, standards, and foundations layers.

---

## Question

Does the `Kernel.Memory` domain re-implement concepts from `Memory` (memory-primitives), or does it properly re-use them?

---

## Analysis

### Complete Type Inventory

#### A. Memory Primitives (`Memory.*`)

**Module: Memory Primitives Core** (18 source files)

| Type | Kind | Purpose |
|------|------|---------|
| `Memory` | enum (namespace) | Root namespace |
| `Memory.Address` | typealias `Tagged<Memory, Ordinal>` | Non-null memory address |
| `Memory.Address.Error` | enum | `.null` for optional pointer conversion |
| `Memory.Alignment` | struct | Power-of-2 alignment (exponent-backed) |
| `Memory.Alignment.Align` | tag | Directional alignment operations (`up`, `down`) |
| `Memory.Alignment.Error` | enum | `.notPowerOfTwo`, `.shiftExceedsBitWidth` |
| `Memory.Shift` | struct | Bit shift count (0–63) |
| `Memory.Shift.Error` | enum | `.outOfRange` |
| `Memory.Allocation` | enum (namespace) | Allocation tracking (empty at primitives) |
| `Memory.Inline<Element, capacity>` | struct | Fixed-capacity inline storage (@_rawLayout) |
| `Memory.Aligned` | protocol | Power-of-2 alignment requirement |

**Module: Memory Primitives Standard Library Integration** (9 source files)

| Extension Target | Operations |
|------------------|------------|
| `UnsafeRawPointer` | `advanced(by: Memory.Address.Offset)`, `load(fromByteOffset:)` |
| `UnsafeMutableRawPointer` | `advanced(by:)`, `store(_:at:)`, memory operations |
| `UnsafeRawBufferPointer` | Buffer-level operations with typed offsets |
| `UnsafeMutableRawBufferPointer` | Mutable buffer operations with typed offsets |
| `Array` | Interop extensions |

**Module: Memory Primitives** (umbrella, 6 source files)

| Type | Kind | Purpose |
|------|------|---------|
| `Memory.Buffer` | struct | Non-null immutable raw buffer (sentinel-backed) |
| `Memory.Buffer.Mutable` | struct | Non-null mutable raw buffer (sentinel-backed) |
| `Memory.Allocator.Protocol` | protocol (~Copyable) | Allocation strategy interface |
| `Memory.Allocator` | struct | System allocator (UnsafeMutableRawPointer) |

**Module: Memory Arena Primitives** (2 source files)

| Type | Kind | Purpose |
|------|------|---------|
| `Memory.Arena` | struct (~Copyable) | Bump allocator with O(1) alloc, bulk reset |
| `Memory.Arena.Error` | enum | `.insufficientCapacity` |

**Module: Memory Pool Primitives** (4 source files)

| Type | Kind | Purpose |
|------|------|---------|
| `Memory.Pool` | struct (~Copyable) | Fixed-slot allocator with in-band free list |
| `Memory.Pool.Slot` | phantom type | Slot-level indexing |
| `Memory.Pool.Error` | enum | `.exhausted`, `.slotSizeTooSmall`, `.foreignPointer`, `.doubleFree` |

---

#### B. Kernel Memory Primitives (`Kernel.Memory.*`)

**Module: Kernel Primitives Core** (1 file)

| Type | Kind | Purpose |
|------|------|---------|
| `Kernel.Memory` | enum (namespace) | Kernel memory operations root |

**Module: Kernel Memory Primitives** (21 source files)

| Type | Kind | Re-uses from memory-primitives? |
|------|------|-------------------------------|
| `Kernel.Memory.Address` | typealias `Tagged<Kernel, Memory_Primitives_Core.Memory.Address>` | **YES** — wraps `Memory.Address` with Kernel phantom tag |
| `Kernel.Memory.Displacement` | typealias `Tagged<Kernel, Memory.Address.Offset>` | **YES** — wraps `Memory.Address.Offset` |
| `Kernel.Memory.Page` | enum (namespace) | New concept (OS page management) |
| `Kernel.Memory.Page.Size` | typealias `Tagged<Kernel.Memory.Page, Cardinal>` | Uses `Cardinal` from primitives |
| `Kernel.Memory.Map` | enum (namespace) | New concept (mmap/VirtualAlloc interface) |
| `Kernel.Memory.Map.Region` | struct | New — `(base: Kernel.Memory.Address, length: Kernel.File.Size)` |
| `Kernel.Memory.Map.Protection` | struct (OptionSet) | New — OS-level page protection flags |
| `Kernel.Memory.Map.Flags` | struct (OptionSet) | New — OS-level mapping flags |
| `Kernel.Memory.Map.Advice` | enum | New — madvise hint values |
| `Kernel.Memory.Map.Sync.Flags` | struct | New — msync flags |
| `Kernel.Memory.Map.Anonymous` | enum (namespace) | New — anonymous mapping interface |
| `Kernel.Memory.Map.File` | enum (namespace) | New — file-backed mapping (Windows) |
| `Kernel.Memory.Map.Error` | enum | New — syscall-level mapping errors |
| `Kernel.Memory.Map.Error.Validation` | enum | New — input validation errors |
| `Kernel.Memory.Lock` | enum (namespace) | New — mlock/VirtualLock interface |
| `Kernel.Memory.Lock.Error` | enum | New — page locking errors |
| `Kernel.Memory.Lock.All` | enum (namespace) | New — mlockall (POSIX-only) |
| `Kernel.Memory.Shared` | enum (namespace) | New — shm_open/CreateFileMapping interface |
| `Kernel.Memory.Shared.Error` | enum | New — shared memory errors |
| `Kernel.Memory.Allocation` | enum (namespace) | New — kernel allocation parameters |
| `Kernel.Memory.Allocation.Granularity` | typealias `Tagged<..., Memory.Alignment>` | **YES** — wraps `Memory.Alignment` |

---

#### C. Platform Implementations (ISO 9945 + Windows)

**POSIX** (swift-iso-9945, Layer 2):
Extensions on `Kernel.Memory.Map`, `Kernel.Memory.Lock`, `Kernel.Memory.Shared` providing actual syscall wrappers (`mmap()`, `munmap()`, `mlock()`, `shm_open()`, etc.).

**Windows** (swift-windows-primitives, Layer 1):
Extensions on `Kernel.Memory.Map`, `Kernel.Memory.Lock`, `Kernel.Memory.Shared` providing Windows API wrappers (`CreateFileMappingW()`, `VirtualAlloc()`, `VirtualLock()`, etc.).

**No types redefined** — both platform packages extend the Kernel Primitives namespaces.

---

#### D. Foundations Memory (`Memory.*` in swift-memory)

**Module: Memory** (23 source files)

| Type | Kind | Re-uses from lower layers? |
|------|------|---------------------------|
| `Memory.Map` | struct (~Copyable) | **YES** — wraps `Kernel.Memory.Map.Region?` with RAII |
| `Memory.Map.Index` | typealias `Tagged<Memory.Map, Ordinal>` | Uses `Ordinal` from primitives |
| `Memory.Map.Offset` | typealias | Automatic from Index |
| `Memory.Map.Range` | enum | New — `.bytes(offset:, length:)` or `.whole` |
| `Memory.Map.Access` | struct (OptionSet) | New — user-facing `.read`, `.write` (maps to `Kernel.Memory.Map.Protection`) |
| `Memory.Map.Sharing` | enum | New — `.shared`, `.private` (maps to `Kernel.Memory.Map.Flags`) |
| `Memory.Map.Safety` | enum | New — `.coordinated(kind, scope)`, `.unchecked` |
| `Memory.Error` | enum | New — wraps all kernel error types |
| `Memory.Lock.Token` | class | New — RAII file lock holder |
| `Memory.Shared` (extensions) | — | Delegates to `Kernel.Memory.Shared` |
| `Memory.Page` (extensions) | — | Convenience for `Kernel.Memory.Page.Size` → `Memory.Alignment` |
| `Memory.Allocation.Tracker` | enum | New — allocation measurement |
| `Memory.Allocation.Statistics` | struct | New — before/after snapshot delta |
| `Memory.Allocation.Peak` | struct | New — peak usage tracking |
| `Memory.Allocation.Leak` | enum | New — leak detection |
| `Memory.Allocation.Histogram` | struct | New — allocation size distribution |
| `Memory.Allocation.Profiler` | struct | New — comprehensive profiler |
| `Memory.Advice` | — | Re-export of `Kernel.Memory.Map.Advice` |

---

### Re-use Assessment

#### Types That Properly Re-use Memory Primitives

| Kernel/Foundations Type | Wraps | Mechanism |
|------------------------|-------|-----------|
| `Kernel.Memory.Address` | `Memory.Address` | `Tagged<Kernel, Memory.Address>` — phantom-tagged wrapper |
| `Kernel.Memory.Displacement` | `Memory.Address.Offset` | `Tagged<Kernel, Memory.Address.Offset>` |
| `Kernel.Memory.Allocation.Granularity` | `Memory.Alignment` | `Tagged<Kernel.Memory.Allocation, Memory.Alignment>` |
| `Kernel.Memory.Page.Size` → `.alignment` | `Memory.Alignment` | Conversion via `Memory.Alignment.init(Kernel.Memory.Page.Size)` |
| `Memory.Map` (foundations) | `Kernel.Memory.Map.Region` | Stored property `region: Kernel.Memory.Map.Region?` |
| `Memory.Error` (foundations) | All kernel error types | Enum cases wrapping `Kernel.Memory.Map.Error`, etc. |

#### Types That Are Genuinely New (Not Re-implementations)

| Domain | Types | Justification |
|--------|-------|---------------|
| OS virtual memory | `Map`, `Region`, `Protection`, `Flags`, `Advice`, `Sync` | Kernel-specific; no equivalent at memory-primitives level |
| OS page management | `Page`, `Page.Size` | OS concept; memory-primitives is page-agnostic |
| OS page locking | `Lock`, `Lock.All`, `Lock.Error` | mlock/VirtualLock have no userspace equivalent |
| OS shared memory | `Shared`, `Shared.Access`, `Shared.Options` | shm_open/CreateFileMapping have no userspace equivalent |
| RAII mapping | `Memory.Map` (~Copyable) | Policy layer with lock coordination, SIGBUS safety |
| Allocation tracking | `Tracker`, `Statistics`, `Peak`, `Leak`, `Histogram`, `Profiler` | Diagnostic tooling; extends the empty `Memory.Allocation` namespace |

---

### Dependency Flow

```
Memory Primitives Core
  ↓ provides Memory.Address, Memory.Alignment
Kernel Memory Primitives
  ↓ wraps with Tagged<Kernel, ...> phantom tags
  ↓ adds OS-specific namespaces (Map, Lock, Shared, Page)
Platform Implementations (ISO 9945, Windows)
  ↓ extends Kernel.Memory.* with actual syscalls
Kernel (foundations umbrella)
  ↓ re-exports everything
Memory (foundations policy layer)
  ↓ wraps Kernel.Memory.Map.Region with RAII, safety, allocation tracking
```

Every arrow is downward-only. No lateral or upward dependencies.

---

### Namespace Disambiguation

Three distinct `Memory` namespaces exist in the ecosystem:

| Namespace | Package | Domain |
|-----------|---------|--------|
| `Memory.*` | swift-memory-primitives | Userspace memory abstractions (Address, Alignment, Buffer, Allocator, Arena, Pool) |
| `Kernel.Memory.*` | swift-kernel-primitives | OS virtual memory interface (Map, Lock, Shared, Page) |
| `Kernel.System.Memory.*` | swift-kernel-primitives | Physical RAM queries (Capacity, total) |

These are non-overlapping. `Kernel.Memory` is about OS virtual memory management (syscalls). `Memory` is about typed userspace memory operations. `Kernel.System.Memory` is about hardware queries.

---

## Outcome

**Status**: DECISION

### Finding: No Re-implementation Detected

The `Kernel.Memory` domain properly re-uses memory-primitives in all places where overlap would be expected:

1. **Address**: `Kernel.Memory.Address = Tagged<Kernel, Memory.Address>` — wraps, does not redefine.
2. **Alignment**: `Kernel.Memory.Allocation.Granularity = Tagged<..., Memory.Alignment>` — wraps, does not redefine.
3. **Page.Size → Alignment**: Conversion provided via `Memory.Alignment.init(Kernel.Memory.Page.Size)`.
4. **No duplicate Buffer/Allocator/Arena/Pool** at the kernel level — correctly absent.

All types in `Kernel.Memory` that don't wrap memory-primitives types are **genuinely new OS-level concepts** with no userspace equivalent: `Map`, `Region`, `Protection`, `Flags`, `Lock`, `Shared`, `Page`.

### Architecture Validation

| Criterion | Status |
|-----------|--------|
| Kernel.Memory re-uses Memory.Address | Pass — Tagged wrapper |
| Kernel.Memory re-uses Memory.Alignment | Pass — Tagged wrapper + conversion |
| No duplicate allocation strategies | Pass — no Kernel.Arena, Kernel.Pool |
| No duplicate buffer types | Pass — no Kernel.Buffer |
| Dependency direction | Pass — downward only |
| Namespace disambiguation | Pass — three non-overlapping domains |
| Platform implementations extend, not redefine | Pass — all extensions on Kernel.Memory.* |

### One Observation (Not a Finding)

`Memory.Allocation` is defined as an empty namespace in memory-primitives Core, then extended with `Granularity` at the kernel level and `Tracker`/`Statistics`/`Profiler` at the foundations level. This is a deliberate split — the namespace is declared early to allow each layer to add its own concerns — but the split means the `Memory.Allocation` types are **scattered across three packages**. This is architecturally sound (each layer adds its domain-specific types) but worth noting for documentation purposes.

---

## References

- `owned-typed-memory-region-abstraction.md` — owned-typed-region design decision (now `Storage.Contiguous`)
- `foundations-dependency-utilization-audit.md` — Layer 3 dependency audit
- `swift-io-deep-audit.md` — IO layer quality audit (uses Kernel.Memory.Map)
