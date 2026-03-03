# System and Kernel.System Namespace Boundary

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: RECOMMENDATION
tier: 2
applies_to: [swift-system-primitives, swift-kernel-primitives, swift-kernel, swift-systems]
normative: true
---
-->

## Context

The Swift Institute ecosystem has two top-level namespaces for system-level queries:

| Namespace | Package | Layer | Description |
|-----------|---------|-------|-------------|
| `System` | swift-system-primitives | 1 | "Hardware environment information — what exists" |
| `Kernel.System` | swift-kernel-primitives | 1 | "System information queries" |

Both query the same underlying OS interfaces (`sysconf`, `sysctl`, `GetSystemInfo`). The current boundary is unclear:

| Query | Current Location | Nature |
|-------|-----------------|--------|
| Logical CPU count | `System.processorCount` (bare `Int`) | Hardware fact |
| NUMA topology | `System.Topology` (struct) | Hardware fact |
| Logical CPU count (typed) | `Kernel.System.Processor.Count` (`Tagged<..., Cardinal>`) | Hardware fact |
| Physical CPU count | `Kernel.System.Processor.Physical.Count` | Hardware fact |
| Total RAM | `Kernel.System.Memory.Capacity` | Hardware fact |
| Page size | `Kernel.Memory.Page.Size` | Hardware/OS hybrid |
| Allocation granularity | `Kernel.Memory.Allocation.Granularity` | OS fact |
| Max path length | `Kernel.System.Path.Length` | OS limit |
| OS name/version/arch | `Kernel.System.Name` | OS identity |

**Trigger**: The memory domain inventory (`memory-domain-cross-package-inventory.md`) surfaced the question: why is "total installed RAM" under `Kernel.System.Memory` rather than `System.Memory`? Total RAM is a hardware fact — it describes what physically exists.

**Constraint**: `System` (swift-system-primitives) currently has **zero dependencies**. `Kernel.System` (swift-kernel-primitives) depends on `Kernel Primitives Core` and uses `Tagged<..., Cardinal>` for type-safe wrappers. Moving types from `Kernel.System` to `System` would require swift-system-primitives to gain a dependency on cardinal/tagged primitives.

---

## Question

What is the correct boundary between `System` and `Kernel.System`? Specifically: should hardware facts (CPU count, total RAM, page size) live under `System` rather than `Kernel.System`?

---

## Prior Art Survey

### BSD sysctl (strongest precedent)

BSD's `sysctl` MIB hierarchy explicitly separates hardware description from kernel operations:

| MIB | Domain | Examples |
|-----|--------|----------|
| `CTL_HW` | Hardware facts (read-only, immutable) | `HW_NCPU`, `HW_MEMSIZE`, `HW_PAGESIZE`, `HW_MACHINE` |
| `CTL_KERN` | Kernel state (configurable) | `KERN_MAXPROC`, `KERN_HOSTNAME`, `KERN_BOOTTIME` |
| `CTL_VM` | Virtual memory stats | VM paging, swapping |

CPU count, total RAM, page size, and machine architecture all live under `CTL_HW`. Process limits, hostname, and boot time live under `CTL_KERN`. The separation principle is explicit: `CTL_HW` = "what the hardware IS", `CTL_KERN` = "what the kernel DOES".

### Linux kernel sysfs

Linux uses filesystem subtrees for the same separation:

| Path | Domain | Examples |
|------|--------|---------|
| `/sys/devices/system/cpu/` | Hardware topology | Online CPUs, core IDs, die IDs, sibling masks |
| `/sys/devices/system/node/` | NUMA topology | Memory nodes, bandwidth, latency |
| `/sys/devices/system/memory/` | Physical memory blocks | Online/offline memory regions |
| `/sys/kernel/` | Kernel parameters | Tunables, module configuration |
| `/proc/sys/kernel/` | Kernel tunables | Writable kernel parameters |

Hardware description under `/sys/devices/system/`, kernel operations under `/sys/kernel/`. The devicetree is a pure hardware description format — it describes physical reality so the kernel can make data-driven decisions.

### Go

Go scatters hardware facts pragmatically: `runtime.NumCPU()`, `os.Getpagesize()`, `syscall.Sysinfo()`. No dedicated hardware namespace. Page size is in `os` because file I/O needs it; CPU count is in `runtime` because the scheduler needs it.

### Rust

Rust `std` provides no hardware query APIs at all. External crates handle it: `num_cpus` (CPU count), `nix::sys::sysinfo` (RAM, load), `sysinfo` crate (comprehensive). The `nix` crate puts hardware queries and kernel operations as flat siblings under `nix::sys`.

### Apple swift-system

Exclusively operational (file descriptors, paths, permissions). Zero hardware query APIs.

### Synthesis

| Ecosystem | Explicit hw/kernel separation? | Mechanism |
|-----------|-------------------------------|-----------|
| BSD sysctl | **Yes** | `CTL_HW` vs `CTL_KERN` |
| Linux sysfs | **Yes** | `/sys/devices/system/` vs `/sys/kernel/` |
| Go | No | Pragmatic scattering |
| Rust std | No | Omits hardware queries entirely |
| Apple swift-system | No | Omits hardware queries entirely |

The two systems that DO model hardware queries (BSD, Linux) both separate them from kernel operations. The systems that DON'T (Go, Rust std, Apple) simply avoid the domain. **No system puts hardware facts under a "kernel" namespace.**

---

## Analysis

### Option A: Move hardware facts to System (Recommended)

`System` owns all hardware facts with typed wrappers. `Kernel.System` retains only OS-operational queries.

**After migration**:

| Query | Location | Rationale |
|-------|----------|-----------|
| Logical CPU count | `System.Processor.Count` | Hardware fact |
| Physical CPU count | `System.Processor.Physical.Count` | Hardware fact |
| NUMA topology | `System.Topology` (already here) | Hardware fact |
| Total RAM | `System.Memory.Capacity` | Hardware fact |
| Page size | `System.Page.Size` | Hardware fact (MMU property) |
| Max path length | `Kernel.System.Path.Length` | OS limit (configurable) |
| OS name/version | `Kernel.System.Name` | OS identity |
| Allocation granularity | `Kernel.Memory.Allocation.Granularity` | OS parameter (Windows ≠ page size) |
| Alignment helpers | `Kernel.System.align*` | OS operation |
| Sleep | `Kernel.System.sleep` | OS operation |

**Advantages**:
- Aligns with BSD sysctl (`CTL_HW` vs `CTL_KERN`) and Linux sysfs separation
- `System` becomes the single source for "what does this machine have?"
- Clear semantic: `System` = hardware environment, `Kernel` = OS operations
- Eliminates the current duplication where `System.processorCount` (bare `Int`) and `Kernel.System.Processor.Count` (typed) coexist for the same fact
- `System.Memory.Capacity`, `System.Processor.Count` are more natural call sites than `Kernel.System.Memory.Capacity`

**Disadvantages**:
- swift-system-primitives gains dependencies on cardinal-primitives and tagged-primitives (currently zero-dependency)
- Platform delegation pattern must be adopted in swift-system-primitives (currently calls syscalls directly)
- Breaking change for consumers of `Kernel.System.Memory.Capacity` and `Kernel.System.Processor.Count`

**Dependency cost**: swift-system-primitives would need to depend on `Cardinal_Primitives` and `Tagged_Primitives` (both Tier 0, zero-dependency themselves). This is a modest cost — these are leaf packages.

---

### Option B: Keep current split, rename for clarity

Keep `Kernel.System` as-is but document the boundary explicitly. Rename `System` to something like `Hardware` or accept the duplication.

**Advantages**:
- No migration effort
- No new dependencies for swift-system-primitives

**Disadvantages**:
- The boundary remains semantically incoherent: "total RAM" is not a kernel concept
- `System.processorCount` (bare `Int`) and `Kernel.System.Processor.Count` (typed) continue to coexist
- Prior art unanimously says hardware facts don't belong under "kernel"
- Consumers must know which namespace to check for hardware queries

---

### Option C: Absorb System into Kernel.System

Eliminate `System` entirely. Everything becomes `Kernel.System.*`.

**Advantages**:
- One namespace, no ambiguity
- No duplication

**Disadvantages**:
- `Kernel` becomes required for hardware queries — heavy dependency for lightweight needs
- Violates the BSD/Linux principle that hardware facts are independent of the kernel
- NUMA topology discovery (which is purely structural) would be under `Kernel`
- `KERNEL_AVAILABLE` conditional compilation would gate hardware queries — architecturally wrong for embedded targets

---

### Option D: System as complete hardware namespace, typed from the start

Like Option A, but also **remove the bare-`Int` API** (`System.processorCount`) and replace it with a typed wrapper. `System` uses `Tagged` for all quantities.

**After migration**:

```swift
// System owns all hardware facts, fully typed
System.processor.count          → System.Processor.Count (Tagged)
System.processor.physical.count → System.Processor.Count (Tagged)
System.memory.capacity          → System.Memory.Capacity (Tagged)
System.page.size                → System.Page.Size (Tagged)
System.topology()               → System.Topology (struct)
```

**Advantages**:
- All Option A advantages
- No bare-`Int` / typed-wrapper duplication
- Single API surface, fully typed
- Consistent with the ecosystem's `Tagged` discipline

**Disadvantages**:
- All Option A disadvantages (dependencies)
- The existing `System.processorCount: Int` becomes a legacy API
- Slightly larger migration scope

---

### Evaluation Criteria

| Criterion | Weight | A | B | C | D |
|-----------|--------|---|---|---|---|
| Semantic correctness | High | Good | Poor | Moderate | Best |
| Prior art alignment | High | Strong | Weak | Weak | Strong |
| API consistency | High | Good | Poor | Good | Best |
| Migration cost | Medium | Moderate | Zero | High | Moderate |
| Dependency cost | Medium | Low | Zero | N/A | Low |
| No duplication | Medium | Moderate* | Poor | Good | Best |
| Embedded support | Low | Good | Good | Poor | Good |

*Option A still has bare-`Int` `processorCount` alongside typed `Processor.Count` unless explicitly deprecated.

---

### Page Size: The Ambiguous Case

Page size deserves specific analysis. Is it a hardware fact or a kernel parameter?

| Perspective | Classification |
|-------------|---------------|
| BSD sysctl | `CTL_HW` / `HW_PAGESIZE` — hardware fact |
| Physical reality | MMU page table granularity — hardware fact |
| Linux huge pages | Kernel can configure 2MB/1GB huge pages — OS choice |
| Windows large pages | `MEM_LARGE_PAGES` — OS choice |
| ARM multi-page | Hardware supports 4K/16K/64K; OS chooses — hybrid |

**Resolution**: The **base page size** (what `sysconf(_SC_PAGESIZE)` returns) is a hardware fact — the MMU's minimum page table entry granularity. Large/huge pages are kernel policy built on top. BSD places base page size under `CTL_HW`. The base page size belongs in `System`.

Allocation granularity (Windows 64KB vs POSIX page-size) is purely an OS parameter and stays in `Kernel.Memory.Allocation`.

---

### `Kernel.System` Residual

After moving hardware facts to `System`, `Kernel.System` retains:

| Member | Nature |
|--------|--------|
| `Kernel.System.Name` | OS identity (uname — kernel version, not hardware) |
| `Kernel.System.Path.Length` | OS limit (PATH_MAX — kernel/VFS configuration) |
| `Kernel.System.sleep()` | OS operation |
| `Kernel.System.align*()` | Utility functions (on kernel dimension types) |

These are genuinely kernel concepts. `Kernel.System` becomes lean but semantically precise: it answers "what OS am I running and what limits does it impose?"

---

## Outcome

**Status**: RECOMMENDATION

### Decision: Option D — System as complete typed hardware namespace

`System` should be the single, complete, typed namespace for all hardware facts:

```
System.Processor.Count          — logical CPU count (Tagged<System.Processor, Cardinal>)
System.Processor.Physical.Count — physical CPU count
System.Memory.Capacity          — total installed RAM (Tagged<System.Memory, Cardinal>)
System.Page.Size                — base page size (Tagged<System.Page, Cardinal>)
System.Topology                 — NUMA topology (struct, already exists)
```

`Kernel.System` retains only OS-operational queries:

```
Kernel.System.Name              — OS identity (uname)
Kernel.System.Path.Length       — max path length (OS limit)
Kernel.System.sleep()           — sleep operations
Kernel.System.align*()          — alignment utility on kernel dimension types
```

`Kernel.Memory.Allocation.Granularity` stays in `Kernel.Memory` — it is an OS parameter (Windows 64KB ≠ page size).

### Rationale

1. **Prior art is unanimous**: BSD `CTL_HW` and Linux `/sys/devices/system/` both separate hardware facts from kernel operations. No precedent puts hardware facts under a "kernel" namespace.

2. **Semantic correctness**: "How much RAM does this machine have?" is not a kernel question. It is a hardware question that happens to require a syscall to answer — but so does `System.processorCount`, which already lives in `System`.

3. **Single source of truth**: Eliminates the current duplication where `System.processorCount` (bare `Int`) and `Kernel.System.Processor.Count` (typed `Tagged`) coexist for the same fact.

4. **Typed from the start**: All quantities use `Tagged` wrappers, consistent with the ecosystem's discipline. The bare-`Int` `System.processorCount` becomes deprecated in favor of `System.processor.count` (typed).

5. **Dependency cost is acceptable**: swift-system-primitives gains dependencies on `Cardinal_Primitives` and `Tagged_Primitives` — both Tier 0 leaf packages with zero transitive dependencies.

### Implementation Path

| Phase | Action | Scope |
|-------|--------|-------|
| 1 | Add `Cardinal_Primitives`, `Tagged_Primitives` dependencies to swift-system-primitives | Package.swift |
| 2 | Define `System.Processor.Count`, `System.Memory.Capacity`, `System.Page.Size` types in swift-system-primitives | 3 new files |
| 3 | Add platform delegation (same pattern as Kernel: namespace in primitives, impl in ISO 9945 / Windows / Darwin / Linux) | Extensions in platform packages |
| 4 | Add cross-platform accessors (`System.processor.count`, `System.memory.capacity`, `System.page.size`) in swift-systems (foundations) | 3 new files |
| 5 | Deprecate `Kernel.System.Processor.Count`, `Kernel.System.Memory.Capacity` with typealiases pointing to `System.*` | Soft migration |
| 6 | Deprecate bare-`Int` `System.processorCount` in favor of typed `System.processor.count` | Soft migration |
| 7 | Migrate consumers | Across all packages |

### Open Question

Should `System.Page.Size` live directly in `System` or remain exclusively in `Kernel.Memory.Page.Size`? Arguments both ways:
- **For `System.Page.Size`**: BSD puts it under `CTL_HW`; it's the MMU's minimum granularity; consumers querying "what hardware do I have?" expect it in `System`.
- **For `Kernel.Memory.Page.Size`**: The primary consumers are memory-mapping operations which already depend on `Kernel.Memory`; moving it duplicates the concept across two namespaces.

The recommendation is `System.Page.Size` as the canonical home, with `Kernel.Memory.Page.Size` becoming a typealias. But this is the one item where either placement is defensible.

---

## References

- BSD `sysctl(2)` — `CTL_HW` vs `CTL_KERN` MIB hierarchy (OpenBSD manual)
- Linux sysfs — `/sys/devices/system/` vs `/sys/kernel/` separation (kernel.org documentation)
- Linux devicetree usage model — pure hardware description (kernel.org)
- Go `runtime.NumCPU()`, `os.Getpagesize()` — pragmatic scattering pattern
- Rust `nix::sys::sysinfo` — flat `nix::sys` organization
- Apple swift-system — operational-only scope, zero hardware queries
- `memory-domain-cross-package-inventory.md` — triggered this investigation
