# ISO 9945 Kernel Modularization Analysis

> Date: 2026-04-10
> Updated: 2026-04-10 — Implementation complete
> Status: **IMPLEMENTED** — Option A (Full Domain Split) shipped
> Scope: Whether `ISO 9945 Kernel` (97 files, 11,834 lines) should be split into domain-specific targets

---

## Context

`ISO 9945 Kernel` is a single monolithic target at L2 (Standards) that provides POSIX
syscall wrappers for all kernel domains: file I/O, sockets, memory mapping, process
management, signals, threads, terminals, and system queries. It extends L1 vocabulary
types from `swift-kernel-primitives` with POSIX-specific implementations.

### Consumers

| Consumer | Layer | Package | Usage |
|----------|-------|---------|-------|
| `swift-posix` | L3 | `swift-foundations/swift-posix/` | Imports `ISO 9945 Kernel` (whole product) |
| `swift-linux-standard` | L2 | `swift-linux-foundation/swift-linux-standard/` | Imports `ISO 9945 Kernel` (two targets) |

Both consumers import the entire product. No consumer currently selectively imports a
subset of POSIX kernel functionality.

### L1 Precedent

`swift-kernel-primitives` (L1) is already modular with 23 targets organized by kernel
domain. ISO 9945 Kernel extends these L1 namespaces:

| L1 Target | L2 Extension (ISO 9945 Kernel) |
|-----------|-------------------------------|
| Kernel Primitives Core | Descriptor veneer, Error.captureErrno() |
| Kernel File Primitives | File.Open, File.Seek, File.Stats, etc. |
| Kernel IO Primitives | IO.Read, IO.Write |
| Kernel Socket Primitives | Socket.getError, Socket.Pair |
| Kernel Memory Primitives | Memory.Map (mmap/munmap/mprotect) |
| Kernel Process Primitives | Process.Fork, Process.Wait, Process.Spawn |
| Kernel Thread Primitives | Thread.Mutex, Thread.Condition |
| Kernel Terminal Primitives | Termios, TTY |
| Kernel System Primitives | System.Name, uname |
| Kernel Time/Clock Primitives | Clock.Continuous, nanosleep |
| Kernel Environment Primitives | Environment get/set/entries |
| *(no L1 equivalent)* | Signal (entire domain is L2-only) |

---

## Step 1: File Inventory by POSIX Domain

| Domain | Files | Lines | Representative Files |
|--------|-------|-------|---------------------|
| **Error / Base** | 6 | ~417 | `Kernel.swift`, `Error.swift`, `Error.Code.swift`, `Error.Number.swift`, `Error.Mapping.swift`, `exports.swift` |
| **File** (incl. IO, Close, Descriptor, Device, Link, Path, Pipe, Lock, Directory) | 30 | ~3,489 | `File.Open.swift`, `IO.Read.swift`, `IO.Write.swift`, `Directory.swift`, `Link.Symbolic.swift`, `Lock.swift`, `Pipe.swift`, `Path.Canonical.swift` |
| **Socket** | 5 | 409 | `Socket.swift`, `Socket.Pair.swift`, `Socket.Shutdown.swift` |
| **Memory** | 15 | 1,093 | `Memory.Map.swift`, `Memory.Shared.swift`, `Memory.Lock.All.swift` |
| **Process** | 12 | 1,326 | `Process.Fork.swift`, `Process.Wait.swift`, `Process.Spawn.swift`, `Process.Status.swift`, `Process.Kill.swift` |
| **Signal** | 11 | 1,496 | `Signal.Number.swift`, `Signal.Action.swift`, `Signal.Mask.swift`, `Signal.Send.swift`, `Signal.Set.swift` |
| **Thread** | 4 | 588 | `Thread.Mutex.swift`, `Thread.Condition.swift`, `Thread.Handle.swift` |
| **Terminal** | 4 | 372 | `Termios.swift`, `TTY.swift`, `Terminal.swift`, `Terminal.Stream.Read.swift` |
| **Time / Clock** | 4 | 295 | `Clock.swift`, `Clock.Continuous.swift`, `Time.swift`, `CPU.Atomic.Flag.swift` |
| **Environment** | 3 | 380 | `Environment.swift`, `Environment.Entries.swift`, `Environment.Error.swift` |
| **System** | 3 | 165 | `System.swift`, `System.Name.swift`, `Random.swift` |
| **Total** | **97** | **11,834** | |

---

## Step 2: Cross-Domain Dependency Analysis

### Methodology

Every file in the target has an identical 18-line import block importing ALL L1 kernel
primitive modules. Import statements provide no signal about actual coupling. Analysis
was performed by examining actual type usage in function signatures, return types,
parameters, and expressions.

### L1 vs L2 Dependency Distinction

Most apparent cross-domain coupling is through **L1 vocabulary types**, not L2 types.
This distinction is critical:

| Type | Defined At | Used By |
|------|-----------|---------|
| `Kernel.Descriptor` | L1 Core | File, Socket, Memory, Pipe, Lock, Directory, IO, Terminal |
| `Kernel.File.Size` | L1 Core | File, Memory (mmap length) |
| `Kernel.File.Offset` | L1 Core | File, IO (pread/pwrite), Memory (mmap offset) |
| `Kernel.Process.ID` | L1 Process | Process, Signal (Send.toProcess) |
| `Kernel.Error.Code` | L1 Error | All domains |
| `Kernel.Pipe.Error` | L1 File | Pipe |
| `Kernel.Socket.Error` | L1 Socket | Socket |
| `POSIX.Kernel.Signal.Number` | **L2 Signal** | Process (Status) |
| `POSIX.Kernel.Process.Group.ID` | **L2 Process** | Signal (Send.toGroup) |
| `POSIX.Kernel.Error.captureErrno()` | **L2 Base** | ~23 files across all domains |
| `POSIX.Kernel.Process.Error` | **L2 Process** | Process only |
| `POSIX.Kernel.Signal.Error` | **L2 Signal** | Signal only |

### Genuine L2 Cross-Domain Dependencies

Only **two** cross-domain references exist at L2:

> **SUPERSEDED** — The analysis below predicted Process → Signal as the only L2 cross-domain edge and assumed Process.Group.ID would promote to L1. Neither happened. Implementation placed both Signal.Number and Process.Group.ID in Core as cycle-breakers, eliminating the Process → Signal edge entirely. Two unforeseen edges emerged instead: Terminal → File and Lock → System. See [Implementation Status](#implementation-status-2026-04-10) for the actual dependency graph.

1. **Process → Signal**: `Process.Status` (`:148`, `:160`, `:204`, `:207`) references
   `POSIX.Kernel.Signal.Number` for decoding WTERMSIG/WSTOPSIG from wait status.

2. **Signal → Process** *(eliminated by L1 promotion)*: `Signal.Send` (`:128`) references
   `POSIX.Kernel.Process.Group.ID`. Per architectural decision, `Process.Group.ID`
   promotes to L1 (`Kernel Process Primitives`), resolving this as an L1 dependency.

**Result**: After L1 promotion, the only genuine L2 cross-domain dependency is
**Process → Signal** (unidirectional).

### All Domains → Core

`POSIX.Kernel.Error.captureErrno()` is referenced by ~23 files across Memory, Process,
Signal, Lock, File, Socket, Pipe. This is the universal L2 dependency — every domain
needs errno capture. It belongs in Core.

### C Shim Dependencies

| Shim | Used By | Files |
|------|---------|-------|
| `CPOSIXProcessShim` | Process domain only | `Process.Execute.swift`, `Process.Spawn.swift`, `Process.Fork.swift`, `Process.Status.swift` |
| `CISO9945Shim` | Memory + Terminal | `Memory.Shared.swift`, `TTY.swift` |

Shim usage is domain-localized — no shim spans all domains.

> **SUPERSEDED** — This matrix assumed Process → Signal and no other cross-domain edges. Actual implementation: Process and Signal are peers (both get vocabulary from Core), Terminal depends on File, Lock depends on System. See [Implementation Status](#implementation-status-2026-04-10).

### Dependency Matrix (L2 internal, after L1 promotion)

```
              Core  File  Socket  Memory  Process  Signal  Thread  Terminal  System
Core           -
File           ✓     -
Socket         ✓           -
Memory         ✓                   -
Process        ✓                            -        ✓
Signal         ✓                                      -
Thread         ✓                                              -
Terminal       ✓                                                       -
System         ✓                                                                -
```

All domains depend on Core. Only Process depends on one sibling (Signal).
No cycles. No diamonds.

---

## Step 3: Split Options

### Option A: Full Domain Split (9 targets + umbrella)

| Target | Files | Lines | L1 Dependencies | L2 Dependencies | C Shims |
|--------|-------|-------|-----------------|-----------------|---------|
| `ISO 9945 Kernel Core` | 6 | ~417 | Kernel Primitives Core, Kernel Error Primitives, Kernel Descriptor Primitives | ISO 9945 | — |
| `ISO 9945 Kernel File` | 30 | ~3,489 | Kernel File, IO, Descriptor, Permission, Path Primitives | Core | — |
| `ISO 9945 Kernel Socket` | 5 | 409 | Kernel Socket Primitives | Core | — |
| `ISO 9945 Kernel Memory` | 15 | 1,093 | Kernel Memory Primitives | Core | CISO9945Shim |
| `ISO 9945 Kernel Signal` | 11 | 1,496 | Kernel Syscall Primitives | Core | — |
| `ISO 9945 Kernel Process` | 12 | 1,326 | Kernel Process, Syscall Primitives | Core, Signal | CPOSIXProcessShim |
| `ISO 9945 Kernel Thread` | 4 | 588 | Kernel Thread Primitives | Core | — |
| `ISO 9945 Kernel Terminal` | 4 | 372 | Kernel Terminal Primitives | Core | CISO9945Shim |
| `ISO 9945 Kernel System` | 10 | 644 | Kernel System, Time, Clock, Random, Environment Primitives | Core | — |
| `ISO 9945 Kernel` (umbrella) | 1 | ~20 | — | All above | — |

> **SUPERSEDED** — This graph shows Process → Signal. Actual implementation: Process and Signal are peers at depth 1. Terminal → File and Lock → System are the actual cross-domain edges. See [Implementation Status](#implementation-status-2026-04-10).

**Dependency graph**:
```
                    ISO 9945 Kernel Core
                    /  |  |  |  |  \  \  \
                   /   |  |  |  |   \  \  \
               File Socket Mem Signal Thread Term System
                              |
                           Process
```

Max depth: **2** (Core → Signal → Process). Satisfies [MOD-007] (threshold ≤ 3).

**Assessment per [MOD-008]**:

| Criterion | Verdict |
|-----------|---------|
| Different dependency set | **Yes** — each target needs different L1 primitives. File needs 5 L1 targets; Socket needs 1; Memory needs 1. Current monolith imports all 18 indiscriminately. |
| Independent consumer value | **Moderate** — current consumers import everything. Future L3/L4 consumers (e.g., a socket-only networking library) would benefit from selective import. |
| Depended-on by siblings | **Signal only** — depended on by Process. All others are leaves. |
| Semantic independence | **Yes** — each target maps to a distinct POSIX specification chapter and L1 primitive domain. |

**Pros**:
- Mirrors L1 target structure — spec↔vocabulary alignment is immediately legible
- Build parallelism: 8 targets compile in parallel after Core; theoretical speedup ~8x
- Import precision: each target declares only its actual L1 dependencies (vs current 18-import-everything)
- C shim dependencies become precise (CPOSIXProcessShim only in Process, CISO9945Shim only in Memory + Terminal)
- Selective consumer import enabled for future packages

**Cons**:
- `@inlinable` annotation burden for cross-target specialization (most syscall wrappers are already small `@inlinable` static functions)
- Package.swift complexity increases (10 targets vs 1)
- Current consumers still import the umbrella — no immediate consumer-side benefit
- File target (30 files) is disproportionately large relative to System (10 files) and Thread (4 files)

### Option B: Partial Split (4-5 targets)

Group domains by shared characteristics:

| Target | Domains | Files | Lines |
|--------|---------|-------|-------|
| `ISO 9945 Kernel Core` | Error, base | 6 | ~417 |
| `ISO 9945 Kernel File` | File, IO, Directory, Link, Lock, Path, Pipe, Socket, Memory, Terminal | 54 | ~5,363 |
| `ISO 9945 Kernel Process` | Process, Signal | 23 | ~2,822 |
| `ISO 9945 Kernel System` | System, Thread, Time, Clock, Environment, Random | 14 | 1,232 |
| `ISO 9945 Kernel` (umbrella) | — | 1 | ~10 |

**Assessment**:

This groups everything descriptor-based into File (54 files), everything
process-lifecycle-related into Process (23 files), and miscellaneous into System.

**Pros**:
- Simpler Package.swift (5 targets vs 10)
- Eliminates the Process→Signal cross-target dependency (merged)
- Broader groupings mean fewer `@inlinable` boundaries

**Cons**:
- File target (54 files, 5,363 lines) is half the entire codebase — barely modularized
- Semantic groupings are forced: Socket ≠ File, Memory ≠ Terminal, Thread ≠ Random
- Doesn't align with L1 structure — L1 has Socket, Memory, Terminal as separate targets
- Violates [MOD-DOMAIN]: "File" would contain Socket (a distinct POSIX subsystem)
- Build parallelism limited: only 3 targets in parallel after Core

### Option C: Keep Monolith

**Assessment**:

| Criterion | Verdict |
|-----------|---------|
| Consumer pattern | All consumers import everything — no demonstrated selective need |
| L2 coupling | Minimal (1 cross-domain edge), but error base is universal |
| Size | 97 files / 11,834 lines — large but not unprecedented at L2 |
| Build impact | Single target compiles sequentially; no parallelism within |

**Pros**:
- Zero Package.swift complexity increase
- No `@inlinable` cross-target burden
- No risk of getting the boundaries wrong
- All consumers already import the whole product

**Cons**:
- Every file imports all 18 L1 kernel primitive modules whether needed or not
- No build parallelism (all 97 files are one compilation unit)
- Doesn't align with L1's modular structure
- Cannot express per-domain C shim dependencies (both shims are always linked)
- Violates [MOD-008] criterion 1 (different dependency sets exist) and criterion 4 (semantic independence exists)
- Growth concern: as more POSIX features are implemented, the monolith only gets larger

---

## Step 4: Recommendation

**Recommended: Option A (Full Domain Split) — 12 domain targets + umbrella**

> **SUPERSEDED** — The recommendation below assumed one cross-domain edge (Process → Signal) and an L1 promotion prerequisite. Implementation diverged: both vocabulary types went to Core instead of L1, eliminating Process → Signal. Two unforeseen edges emerged (Terminal → File, Lock → System). See [Implementation Status](#implementation-status-2026-04-10).

The analysis shows clean domain separation with minimal L2 cross-domain coupling
(exactly one edge: Process → Signal, after promoting `Process.Group.ID` to L1).

### Decisions Made

| Item | Decision | Rationale |
|------|----------|-----------|
| Process ↔ Signal cycle | ~~Promote `Process.Group.ID` to L1~~ **SUPERSEDED**: both types placed in Core at L2 | Originally argued as kernel vocabulary; implementation correctly identified it as POSIX-specific |
| Directory | Separate target | Distinct POSIX subsystem; no L2 File dependency |
| Lock | Separate target | File locking ≠ file I/O; no L2 File dependency |
| Environment | Separate from System | Distinct POSIX concept with own error type |
| ISO 9945 ABI | Absorbed into Core | CChar↔UInt8 projections used by 17 files across 6 domains; `package`-scoped, so Core (universal dep) is the natural home |
| ISO 9945 Core | Internal target, not published | Per [MOD-001]: Core is scaffolding, not a consumer-facing product |

### Rationale

1. **[MOD-DOMAIN] compliance**: Each proposed target represents a coherent POSIX
   specification chapter — a semantic domain, not a code convenience grouping.

2. **L1 alignment**: L1 already invested in 23 domain-specific targets. L2 should
   mirror this structure so the spec↔vocabulary relationship is immediately legible.
   Each L2 target extends exactly the L1 targets it corresponds to.

3. **Dependency precision**: The current 18-import-everything pattern in every file
   is the exact anti-pattern [MOD-002] warns against. Splitting centralizes each
   domain's L1 dependencies and makes them explicit.

4. **C shim isolation**: `CPOSIXProcessShim` is only needed by Process (4 files).
   `CISO9945Shim` is only needed by Memory (1 file) and Terminal (1 file). The
   monolith links both shims unconditionally.

5. **Build parallelism**: 11 independent targets after Core (10 at depth 1, Process
   at depth 2). Brent's theorem: with depth 2 and 12 non-umbrella targets, theoretical
   max parallelism ≈ 6x over the sequential monolith.

6. **Growth safety**: POSIX has many more syscalls that could be added (poll, select,
   epoll wrappers, additional ioctl operations, etc.). Domain targets prevent the
   monolith from growing unboundedly.

7. **ABI absorption**: The `ISO 9945 ABI` target's CChar↔UInt8 projections are used
   by 17 files across File, Directory, Link, Path, Environment, and Process. Absorbing
   into Core eliminates a target and makes the projections universally available via
   the transitive Core dependency.

> **SUPERSEDED** — This prerequisite was abandoned. Process.Group.ID stayed at L2 (ISO 9945 Core) because it is a POSIX-specific concept, not cross-platform vocabulary. The cycle was broken by placing both Process.Group.ID and Signal.Number in Core, not by L1 promotion. See [Workflow B findings](l1-process-signal-vocabulary.md).

### Prerequisite

Promote `POSIX.Kernel.Process.Group.ID` from L2 (`ISO 9945.Kernel.Process.Group.swift`)
to L1 (`Kernel Process Primitives`). This:
- Breaks the Process ↔ Signal cycle at L2
- Is semantically justified: process group IDs are kernel vocabulary, not POSIX-specific
- L1 already has `Kernel.Group.swift` in `Kernel Process Primitives` — natural home
- Minimal change: move a `Tagged<..., pid_t>` typealias and its `.current` constant

### Target Structure

#### Dependency Graph

```
                        ISO 9945 Core (internal, not published)
                 /    /    |    |     |     \    \     \     \    \
              File  Dir  Lock Socket Mem  Signal Thread Term  Env System
                                           |
                                        Process

ISO 9945 Kernel (umbrella) — re-exports all above
```

Max depth: **2** (Core → Signal → Process). All other targets at depth 1.

#### Target Inventory

| # | Target | Files | ~Lines | L1 Deps | C Shims | Extra Deps |
|---|--------|-------|--------|---------|---------|------------|
| 1 | ISO 9945 Core | 8 | 516 | Kernel Primitives Core, Descriptor, Error | — | Path_Primitives |
| 2 | ISO 9945 Kernel File | 20 | 2,317 | Kernel File, IO, Permission, Path | — | Algebra, Identity |
| 3 | ISO 9945 Kernel Directory | 4 | 648 | Kernel File | — | String_Primitives |
| 4 | ISO 9945 Kernel Lock | 3 | 524 | Kernel File | — | — |
| 5 | ISO 9945 Kernel Socket | 5 | 409 | Kernel Socket | — | Algebra |
| 6 | ISO 9945 Kernel Memory | 15 | 1,093 | Kernel Memory | CISO9945Shim | — |
| 7 | ISO 9945 Kernel Signal | 11 | 1,496 | Kernel Process, Syscall | — | — |
| 8 | ISO 9945 Kernel Process | 12 | 1,326 | Kernel Process, Syscall | CPOSIXProcessShim | — |
| 9 | ISO 9945 Kernel Thread | 4 | 588 | Kernel Thread | — | — |
| 10 | ISO 9945 Kernel Terminal | 4 | 372 | Kernel Terminal | CISO9945Shim | Terminal_Primitives |
| 11 | ISO 9945 Kernel Environment | 3 | 380 | Kernel Environment | — | String_Primitives |
| 12 | ISO 9945 Kernel System | 7 | 584 | Kernel System, Time, Clock, Random | — | Clock_Primitives |
| 13 | ISO 9945 Kernel (umbrella) | 1 | ~25 | — | — | — |

#### Core Contents

`ISO 9945 Core` absorbs three current targets into one internal target:

| Source | Files Absorbed | Content |
|--------|---------------|---------|
| `ISO 9945` (target) | `ISO 9945.swift` | Namespace enum, `POSIX` typealias |
| `ISO 9945 ABI` (target) | `ISO 9945.ABI.CChar.swift` | `package`-scoped CChar↔UInt8 pointer projections |
| `ISO 9945 Kernel` (partial) | `Kernel.swift`, `Error.swift`, `Error.Code.swift`, `Error.Number.swift`, `Error.Mapping.swift`, `exports.swift` | `ISO_9945.Kernel` typealias, Descriptor veneer, `Error.captureErrno()`, error code types, L1 re-exports |

Core re-exports via `exports.swift`:
```swift
@_exported public import Kernel_Primitives_Core
@_exported public import Kernel_Descriptor_Primitives
@_exported public import Kernel_Error_Primitives
```

#### File Distribution

After extracting Directory (4) and Lock (3), the File target contains 20 files:

| Sub-domain | Files |
|------------|-------|
| File ops | `File.Open.swift`, `File.Open.Mode.swift`, `File.Open.Options.swift`, `File.Seek.swift`, `File.Stats.Get.swift`, `File.Flush.swift`, `File.Control.swift`, `File.Chown.swift`, `File.Delete.swift`, `File.Move.swift`, `File.Attributes.swift`, `File.Times.swift` |
| IO | `IO.Read.swift`, `IO.Write.swift`, `IO.Read+Terminal.swift` |
| Descriptor | `Close.swift`, `Descriptor.Duplicate.swift` |
| Device | `Device.swift` |
| Link | `Link.swift`, `Link.Symbolic.swift` |
| Path | `Path.Canonical.swift`, `Path.View+Path.Protocol.swift` |
| Pipe | `Pipe.swift` |

> **Note**: File (20 files) remains the largest variant. Link (2 files) and Path (2 files)
> could be further extracted if future growth warrants it, but per [MOD-008] criterion 3,
> 2-file targets with no dependents are borderline. Pipe (1 file) should not be a separate
> target.

#### Package.swift Structure (proposed)

```swift
products: [
    .library(name: "ISO 9945 Kernel", targets: ["ISO 9945 Kernel"]),
    .library(name: "ISO 9945 Kernel File", targets: ["ISO 9945 Kernel File"]),
    .library(name: "ISO 9945 Kernel Directory", targets: ["ISO 9945 Kernel Directory"]),
    .library(name: "ISO 9945 Kernel Lock", targets: ["ISO 9945 Kernel Lock"]),
    .library(name: "ISO 9945 Kernel Socket", targets: ["ISO 9945 Kernel Socket"]),
    .library(name: "ISO 9945 Kernel Memory", targets: ["ISO 9945 Kernel Memory"]),
    .library(name: "ISO 9945 Kernel Signal", targets: ["ISO 9945 Kernel Signal"]),
    .library(name: "ISO 9945 Kernel Process", targets: ["ISO 9945 Kernel Process"]),
    .library(name: "ISO 9945 Kernel Thread", targets: ["ISO 9945 Kernel Thread"]),
    .library(name: "ISO 9945 Kernel Terminal", targets: ["ISO 9945 Kernel Terminal"]),
    .library(name: "ISO 9945 Kernel Environment", targets: ["ISO 9945 Kernel Environment"]),
    .library(name: "ISO 9945 Kernel System", targets: ["ISO 9945 Kernel System"]),
    .library(name: "ISO 9945 Loader", targets: ["ISO 9945 Loader"]),
    .library(name: "ISO 9945 Kernel Test Support", targets: ["ISO 9945 Kernel Test Support"]),
],
targets: [
    // MARK: - Core (internal — not a published product)
    .target(name: "ISO 9945 Core",
        dependencies: [
            .product(name: "Kernel Primitives Core", package: "swift-kernel-primitives"),
            .product(name: "Kernel Descriptor Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Error Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Path Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - File
    .target(name: "ISO 9945 Kernel File",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel File Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel IO Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Permission Primitives", package: "swift-kernel-primitives"),
            .product(name: "Algebra Primitives", package: "swift-algebra-primitives"),
        ]),

    // MARK: - Directory
    .target(name: "ISO 9945 Kernel Directory",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel File Primitives", package: "swift-kernel-primitives"),
            .product(name: "String Primitives", package: "swift-string-primitives"),
        ]),

    // MARK: - Lock
    .target(name: "ISO 9945 Kernel Lock",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel File Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - Socket
    .target(name: "ISO 9945 Kernel Socket",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel Socket Primitives", package: "swift-kernel-primitives"),
            .product(name: "Algebra Primitives", package: "swift-algebra-primitives"),
        ]),

    // MARK: - Memory
    .target(name: "ISO 9945 Kernel Memory",
        dependencies: [
            "ISO 9945 Core",
            .target(name: "CISO9945Shim", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
            .product(name: "Kernel Memory Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - Signal
    .target(name: "ISO 9945 Kernel Signal",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel Process Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Syscall Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - Process
    // SUPERSEDED: proposed Process → Signal dependency was eliminated.
    // Actual implementation: Process depends on Core only (Signal.Number is in Core).
    .target(name: "ISO 9945 Kernel Process",
        dependencies: [
            "ISO 9945 Core",
            "ISO 9945 Kernel Signal",  // ← NOT in actual implementation
            .target(name: "CPOSIXProcessShim", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
            .product(name: "Kernel Process Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Syscall Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - Thread
    .target(name: "ISO 9945 Kernel Thread",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel Thread Primitives", package: "swift-kernel-primitives"),
        ]),

    // MARK: - Terminal
    .target(name: "ISO 9945 Kernel Terminal",
        dependencies: [
            "ISO 9945 Core",
            .target(name: "CISO9945Shim", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
            .product(name: "Kernel Terminal Primitives", package: "swift-kernel-primitives"),
            .product(name: "Terminal Primitives", package: "swift-terminal-primitives"),
        ]),

    // MARK: - Environment
    .target(name: "ISO 9945 Kernel Environment",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel Environment Primitives", package: "swift-kernel-primitives"),
            .product(name: "String Primitives", package: "swift-string-primitives"),
        ]),

    // MARK: - System
    .target(name: "ISO 9945 Kernel System",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Kernel System Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Time Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Clock Primitives", package: "swift-kernel-primitives"),
            .product(name: "Kernel Random Primitives", package: "swift-kernel-primitives"),
            .product(name: "Clock Primitives", package: "swift-clock-primitives"),
        ]),

    // MARK: - Umbrella
    .target(name: "ISO 9945 Kernel",
        dependencies: [
            "ISO 9945 Core",
            "ISO 9945 Kernel File",
            "ISO 9945 Kernel Directory",
            "ISO 9945 Kernel Lock",
            "ISO 9945 Kernel Socket",
            "ISO 9945 Kernel Memory",
            "ISO 9945 Kernel Signal",
            "ISO 9945 Kernel Process",
            "ISO 9945 Kernel Thread",
            "ISO 9945 Kernel Terminal",
            "ISO 9945 Kernel Environment",
            "ISO 9945 Kernel System",
        ]),

    // MARK: - Loader (unchanged, now depends on Core instead of ISO 9945 + ISO 9945 ABI)
    .target(name: "ISO 9945 Loader",
        dependencies: [
            "ISO 9945 Core",
            .product(name: "Loader Primitives", package: "swift-loader-primitives"),
        ]),
]
```

### Naming (per [MOD-012])

L2 Standards naming drops the layer word:

| Role | Name | Import |
|------|------|--------|
| Core | `ISO 9945 Core` | `ISO_9945_Core` |
| Variant | `ISO 9945 Kernel File` | `ISO_9945_Kernel_File` |
| Variant | `ISO 9945 Kernel Directory` | `ISO_9945_Kernel_Directory` |
| Variant | `ISO 9945 Kernel Lock` | `ISO_9945_Kernel_Lock` |
| Variant | `ISO 9945 Kernel Socket` | `ISO_9945_Kernel_Socket` |
| Variant | `ISO 9945 Kernel Memory` | `ISO_9945_Kernel_Memory` |
| Variant | `ISO 9945 Kernel Signal` | `ISO_9945_Kernel_Signal` |
| Variant | `ISO 9945 Kernel Process` | `ISO_9945_Kernel_Process` |
| Variant | `ISO 9945 Kernel Thread` | `ISO_9945_Kernel_Thread` |
| Variant | `ISO 9945 Kernel Terminal` | `ISO_9945_Kernel_Terminal` |
| Variant | `ISO 9945 Kernel Environment` | `ISO_9945_Kernel_Environment` |
| Variant | `ISO 9945 Kernel System` | `ISO_9945_Kernel_System` |
| Umbrella | `ISO 9945 Kernel` | `ISO_9945_Kernel` |

### Consumer Import (per [MOD-015])

This is a **primary decomposition** along the POSIX subsystem axis. Core is scaffolding
(error capture, descriptor veneer, ABI projections); the variants are the product.

- Platform packages (linux-standard, darwin-standard) that need everything: import the
  umbrella `ISO 9945 Kernel` — this is correct for full-platform consumers.
- Future selective consumers (e.g., a socket library, a file I/O library): import
  specific variants like `ISO 9945 Kernel Socket`.

### Targets Absorbed / Eliminated

| Old Target | Disposition |
|------------|-------------|
| `ISO 9945` (target + product) | Absorbed into `ISO 9945 Core`. Product removed — namespace enum has no consumer value alone. |
| `ISO 9945 ABI` (target) | Absorbed into `ISO 9945 Core`. CChar↔UInt8 projections become universally available via Core. |
| `ISO 9945 Kernel` (monolith) | Becomes the umbrella — zero implementation, only `@_exported public import` statements. |

### Metrics (projected)

| Metric | Current | After Split | Threshold |
|--------|---------|-------------|-----------|
| Target count | 1 | 14 (12 + umbrella + Core) | — |
| Max depth | 1 | 2 | ≤ 3 ✓ |
| Mean sibling deps | 0 | 0.08 (1/12) | ≤ 2.0 ✓ |
| Largest target (files) | 97 | 20 (File) | — |
| Largest target (lines) | 11,834 | ~2,317 (File) | — |
| Cross-domain edges | — | 1 (Process→Signal) | — |

---

## Open Items

### Resolved

1. ~~File target granularity~~ → Directory and Lock are separate targets.
2. ~~System target composition~~ → Environment is a separate target.
3. ~~ISO 9945 ABI disposition~~ → Absorbed into Core.

### Remaining (for implementation phase)

1. **`ISO 9945 Kernel Test Support` restructuring**: The current test support target
   depends on the monolith. After split, it should either depend on the umbrella
   (simplest) or be split per-domain (maximum precision). Umbrella dependency is
   recommended for test support — test helpers routinely cross domain boundaries.

2. **`ISO 9945` product removal**: External consumers (if any) that import `ISO 9945`
   for just the namespace enum need to be identified and migrated. Grep for
   `import ISO_9945` across the workspace before removing the product.

3. **`Path_Primitives` in Core**: The current `exports.swift` has
   `internal import Path_Primitives`. Verify whether Core genuinely needs this
   or if it should move to a variant target (File or Directory).

### Implementation Notes (for future reference)

- Each file's 18-line import block must be replaced with target-specific imports
- Core's `exports.swift` should `@_exported public import` its L1 dependencies
- Each variant's `exports.swift` should `@_exported public import ISO_9945_Core`
- Process.Kill.swift now uses `Signal.Number` from Core directly (duplicate `Process.Signal` was removed 2026-04-10)
- Pipe.swift imports `Algebra_Primitives` and `Identity_Primitives` — File target deps
- Socket.Pair.swift imports `Algebra_Primitives` — Socket target dep
- Directory.Working.swift and Environment.swift import `String_Primitives` and
  `Kernel_String_Primitives` — target-specific deps
- ISO 9945 ABI's `package`-scoped extensions remain accessible from all targets
  via the transitive Core dependency (same Swift package)

### ISO 9945 ABI Usage Map (for implementation)

Files that currently `internal import ISO_9945_ABI` (17 files, by proposed target):

| Target | Files using ABI |
|--------|----------------|
| File | `File.Chown`, `File.Open`, `File.Delete`, `File.Attributes`, `File.Stats.Get`, `File.Move`, `File.Times`, `Link.swift`, `Link.Symbolic`, `Path.Canonical` |
| Directory | `Directory.swift`, `Directory.Create`, `Directory.Remove`, `Directory.Working` |
| Environment | `Environment.swift`, `Environment.Entries` |
| Process | `Process.Spawn` |

---

## Implementation Status (2026-04-10)

Option A was implemented as recommended. Both iso-9945 (L2) and swift-posix (L3) are modularized.

### ISO 9945 (L2) — Final Structure

**14 targets total**: Core + 12 domain + umbrella + Loader

| # | Target | Type | Notes |
|---|--------|------|-------|
| 1 | `ISO 9945 Core` | internal | Namespace, errors, ABI projections, cycle-breaker types |
| 2 | `ISO 9945 Kernel File` | product | File I/O, close, descriptor, device, link, path, pipe |
| 3 | `ISO 9945 Kernel Directory` | product | opendir/readdir/closedir |
| 4 | `ISO 9945 Kernel Lock` | product | File locking (flock). **Depends on System.** |
| 5 | `ISO 9945 Kernel Socket` | product | Socket operations |
| 6 | `ISO 9945 Kernel Memory` | product | mmap/munmap/mprotect/shared memory |
| 7 | `ISO 9945 Kernel Signal` | product | sigaction, signal masks, signal sending |
| 8 | `ISO 9945 Kernel Process` | product | fork/exec/wait/spawn. Depends on Signal (via Core). |
| 9 | `ISO 9945 Kernel Thread` | product | pthread_mutex, pthread_cond |
| 10 | `ISO 9945 Kernel Terminal` | product | termios, TTY. **Depends on File.** |
| 11 | `ISO 9945 Kernel Environment` | product | getenv/setenv/environ |
| 12 | `ISO 9945 Kernel System` | product | uname, clock, random, nanosleep |
| 13 | `ISO 9945 Kernel` | umbrella | Re-exports all 12 domain targets |
| 14 | `ISO 9945 Loader` | product | dlopen/dlsym/dlclose |

Plus 2 C shim targets: `CPOSIXProcessShim` (Process only), `CISO9945Shim` (Memory + Terminal).
Plus test support and test targets.

### Cycle-Breaker Types in Core

Two types were placed in Core to break what would otherwise be circular dependencies:

| Type | In Core because |
|------|-----------------|
| `ISO_9945.Kernel.Signal.Number` | Process.Status decodes WTERMSIG/WSTOPSIG, needs Signal.Number. If Signal.Number were in Signal target, Process would depend on Signal, which would create coupling concerns. |
| `ISO_9945.Kernel.Process.Group.ID` | Signal.Send.toGroup needs Process.Group.ID. Placing it in Core (along with Signal enum/Number) means neither Process nor Signal depend on each other at the target level. |

### Cross-Domain Dependencies (actual)

The original analysis predicted Process -> Signal as the only cross-domain edge.
The implementation revealed two additional edges:

```
                    ISO 9945 Core
             /  /  |  |   |   \  \  \  \  \
          File Dir Lock Socket Mem Signal Thread  Env System
            |       |
         Terminal   System
```

| Edge | Mechanism | Rationale |
|------|-----------|-----------|
| Terminal -> File | `@_exported public import ISO_9945_Kernel_File` | Terminal I/O operations need file descriptor types |
| Lock -> System | `@_exported public import ISO_9945_Kernel_System` | File locking needs clock/time types for timed locks |
| Process -> Signal | Resolved via Core | Both Signal.Number and Process.Group.ID live in Core |

Max depth remains **2** (Core -> File -> Terminal, or Core -> System -> Lock).

### POSIX Typealias Removal

The `public typealias POSIX = ISO_9945` was **removed** from L2. The `ISO 9945.swift` file now contains:

```swift
public enum ISO_9945: Sendable {}
// The POSIX typealias is owned by swift-posix (L3), not iso-9945 (L2).
// L2 code uses ISO_9945 directly.
```

The `POSIX` enum is defined in L3 (`swift-posix/Sources/POSIX Core/POSIX.Kernel.swift`):

```swift
public enum POSIX {
    public enum Kernel {
        public enum File {}
    }
}
```

### swift-posix (L3) — Matching Structure

**16 targets**: Core + 12 domain (matching iso-9945) + Glob + Loader + umbrella

10 of the 12 domain targets are re-export-only (single `exports.swift` file):
- Lock, Signal, Thread, Directory, Memory, Socket, Process, Terminal, Environment, System

Each re-export target contains:
```swift
@_exported public import POSIX_Core
@_exported public import ISO_9945_Kernel_<Domain>
```

3 targets have actual L3 code:
- **POSIX Kernel File**: `POSIX.Kernel.File.Flush` and `POSIX.Kernel.IO.Write` (EINTR-retry wrappers)
- **POSIX Kernel Glob**: `POSIX.Kernel.Glob` (new L3 functionality, not in iso-9945)
- **POSIX Core**: `POSIX` enum definition, `Kernel.Error.Code.posixMessage`

### Downstream Consumer Verification

| Consumer | Depends on | Import style | Status |
|----------|-----------|--------------|--------|
| `swift-kernel` | `swift-posix` | `POSIX Kernel` (umbrella, platform-conditional) | OK -- re-exports via `Kernel Core` |
| `swift-linux` | `swift-posix` | 11 individual POSIX Kernel variant targets | OK -- selective import |
| `swift-darwin` | `swift-posix` | 11 individual POSIX Kernel variant targets + Loader | OK -- selective import |
| `swift-console` | `swift-posix` | `POSIX Kernel` (umbrella, platform-conditional) | OK |
| `swift-loader` | `swift-posix` | `POSIX Loader` (platform-conditional) | OK |
| `swift-file-system` | `swift-kernel` | Transitive via Kernel -> POSIX_Kernel | OK -- uses `POSIX.Kernel.File.Flush` |

No consumer references `ISO_9945` directly (outside iso-9945 and swift-posix). All L3+ code uses the `POSIX.` namespace or gets it transitively through `swift-kernel`.

No broken references found from the typealias removal. The `POSIX.` references in `swift-primitives` are to `Kernel.Error.Code.POSIX` (an error code case), not the removed typealias.

### Re-Export-Only Targets Assessment

10 of 16 POSIX targets contain only an `exports.swift` with re-exports. This pattern is acceptable:

1. **Consumer precision**: swift-linux and swift-darwin already import individual variant targets (not the umbrella), demonstrating the value of granular products
2. **Compilation overhead**: Minimal -- re-export-only targets compile near-instantly
3. **Structural alignment**: 1:1 mapping between iso-9945 and POSIX targets makes the layering immediately legible
4. **Growth path**: When EINTR-retry wrappers are added for more domains, the target already exists
