# C Shim Placement Architecture

<!--
---
version: 1.0.0
last_updated: 2026-04-09
status: RECOMMENDATION
decision_tier: 2
---
-->

## Context

`swift-kernel-primitives` contains three C shim targets — `CDarwinShim`, `CLinuxShim`,
`CPosixShim` — that no Swift code in the package actually calls. They exist purely as
build infrastructure consumed by downstream packages through transitive dependencies.

Meanwhile, the platform packages (`swift-linux-primitives`, `swift-darwin-primitives`)
already contain functionally identical C shims (`CLinuxKernelShim`, `CDarwinKernelShim`)
that were duplicated during modularization. And `swift-iso-9945` — the POSIX standard
implementation — explicitly imports all three kernel-primitives shims in 19 source files.

This research determines the correct placement of each C shim target, the disposition
of Linux/Darwin-specific Swift code currently in iso-9945, and whether any shims can
be eliminated entirely.

### Trigger

Console mechanism files were relocated from kernel-primitives to windows-primitives,
which also removed `CWindowsShim` (a Console-only C shim). This surfaced the question:
should the remaining C shims also leave kernel-primitives?

## Question

Where should each C shim target live in the five-layer architecture, and what Swift
code needs to move with it?

## Inventory

### C Shim Targets in kernel-primitives (to be resolved)

| Target | Functions | Consumers | Duplicated? |
|--------|-----------|-----------|-------------|
| `CLinuxShim` | 8 syscall wrappers (copy_file_range, ficlone, io_uring_*, getrandom, renameat2, dup3, pipe2, sched_setaffinity) + headers (epoll, eventfd, statfs, io_uring, O_DIRECT, FICLONE, RENAME_*) | iso-9945 (14 files), linux-primitives (16 files) | Yes — `CLinuxKernelShim` in linux-primitives is identical |
| `CDarwinShim` | swift_shm_open (variadic), swift_fork (unavailable in Swift), swift_RTLD_MAIN_ONLY, swift_RTLD_FIRST | iso-9945 (1 file) | Mostly — `CDarwinKernelShim` in darwin-primitives has all except swift_fork |
| `CPosixShim` | swift_isatty, swift_tcgetattr, swift_tcsetattr, swift_ioctl_tiocgwinsz, swift_RTLD_DEFAULT, swift_RTLD_NEXT | iso-9945 (3 files) | No |

### Established Pattern: iso-9899

`swift-iso-9899` (C standard, ISO/IEC 9899) owns 5 C shim targets for C standard
library functions: `CISO9899Math`, `CISO9899Errno`, `CISO9899String`, `CISO9899Ctype`,
`CISO9899Stdlib`. These live in the standards package because they provide Swift-callable
wrappers for the standard the package implements.

This establishes the principle: **standards packages own the C shims for their standard**.

### Platform Package Shims (already correct)

| Package | Shim | Purpose |
|---------|------|---------|
| swift-linux-primitives | `CLinuxKernelShim` | Linux syscalls, epoll, io_uring, uuid |
| swift-linux-primitives | `CLinuxMemoryShim` | Linux allocation tracking |
| swift-darwin-primitives | `CDarwinKernelShim` | Darwin shm_open, RTLD macros, uuid |
| swift-darwin-primitives | `CDarwinMemoryShim` | Darwin malloc zone stats |
| swift-windows-primitives | `CWindowsMemoryShim` | Windows heap stats |
| swift-arm-primitives | `CARMShim` | ARM register/instruction access |
| swift-x86-primitives | `CX86Shim` | x86 CPUID, RDRAND, RDTSCP |
| swift-cpu-primitives | `CCPUShim` | Cross-arch atomics, barriers, timestamps |

These are correctly placed — each platform/architecture package owns the C shims
for the platform APIs it wraps.

## Analysis

### What iso-9945 Actually Needs from C Shims

Auditing all 19 iso-9945 files that import C shims:

**Genuinely POSIX (belongs in iso-9945):**

| Symbol | Why shim needed | Source today |
|--------|----------------|-------------|
| `swift_ioctl_tiocgwinsz()` | ioctl is variadic | CPosixShim |
| `swift_RTLD_DEFAULT()` | C macro | CPosixShim |
| `swift_RTLD_NEXT()` | C macro | CPosixShim |
| `swift_shm_open()` | Variadic on Darwin | CDarwinShim |
| `swift_tcgetattr()` | Available via Darwin/Glibc directly — **shim unnecessary** | CPosixShim |
| `swift_tcsetattr()` | Available via Darwin/Glibc directly — **shim unnecessary** | CPosixShim |
| `swift_isatty()` | Available via Darwin/Glibc directly — **shim unnecessary** | CPosixShim |

**Linux-specific (does NOT belong in iso-9945):**

| Symbol | What it is | Correct home |
|--------|-----------|--------------|
| `swift_copy_file_range()` | Linux syscall | linux-primitives |
| `swift_ficlone()` | Linux ioctl | linux-primitives |
| `swift_pipe2()` | Linux extension | linux-primitives |
| `swift_getrandom()` | Linux syscall | linux-primitives |
| `swift_renameat2()` | Linux syscall | linux-primitives |

**Header-only imports (9 files import CLinuxShim for defines/types, not functions):**

These files import CLinuxShim to access `O_DIRECT`, `RENAME_NOREPLACE`, `struct statfs`,
`MCL_ONFAULT`, etc. — defines not in SwiftGlibc. These are Linux-specific defines that
belong in `CLinuxKernelShim` (already there). The Swift code accessing them is also
Linux-specific and belongs in the Linux package.

### Option A: Move POSIX shims to iso-9945, remove rest from kernel-primitives

**CPosixShim → iso-9945**: Rename to `CISO9945Shim`. Keep only the 4 functions that
need wrappers (ioctl_tiocgwinsz, RTLD_DEFAULT, RTLD_NEXT, shm_open). Eliminate
unnecessary wrappers (isatty, tcgetattr, tcsetattr — callable directly from
Darwin/Glibc/Musl).

**CLinuxShim → delete**: Identical to `CLinuxKernelShim` in linux-primitives.

**CDarwinShim → delete**: `CDarwinKernelShim` in darwin-primitives has shm_open and
RTLD macros. `swift_fork` is provided by iso-9945's own `CPOSIXProcessShim`.

**Linux Swift code in iso-9945**: 5 files with Linux-specific syscall implementations
move to linux-primitives. They extend `Kernel.*` types (L1), not `ISO_9945.*` types (L2).
This follows the existing pattern where `Linux.Kernel.File.Rename` extends
`Kernel.File.Rename` with renameat2 in linux-primitives.

**Darwin Swift code in iso-9945**: `ISO 9945.Kernel.Copy.Clone.swift` has a Darwin
`clonefile` implementation — moves to darwin-primitives.

**Pros**: Clean separation. Each package owns exactly the C interop it needs.
Eliminates duplication. Follows iso-9899 precedent.

**Cons**: Requires moving Swift files across packages (not just C shims).

### Option B: Keep kernel-primitives shims, just deduplicate

Remove only the exact duplicates (`CLinuxShim`, `CDarwinShim`), keep `CPosixShim` in
kernel-primitives since it's not platform-specific.

**Pros**: Minimal change. CPosixShim stays at the lowest common dependency.

**Cons**: kernel-primitives still contains C shims that no local Swift code uses.
CPosixShim is consumed only by iso-9945 — it's misplaced. Doesn't follow the
iso-9899 pattern. Doesn't resolve the Linux-specific code in iso-9945.

### Option C: Eliminate shims entirely where possible

Some shims exist for functions callable directly from Swift:
- `swift_isatty(fd)` → `Darwin.isatty(fd)` / `Glibc.isatty(fd)`
- `swift_tcgetattr(fd, t)` → `Darwin.tcgetattr(fd, t)` / `Glibc.tcgetattr(fd, t)`
- `swift_tcsetattr(fd, a, t)` → `Darwin.tcsetattr(fd, a, t)` / `Glibc.tcsetattr(fd, a, t)`

These 3 wrappers are unnecessary and should be eliminated regardless of which
option is chosen for placement.

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Follows iso-9899 pattern | Yes | No | N/A (orthogonal) |
| kernel-primitives platform-agnostic | Yes | Partially | N/A |
| Eliminates duplication | Yes | Yes | Reduces shim count |
| Resolves misplaced Swift code | Yes | No | No |
| Scope of change | Large (Swift files move) | Small | Small |
| Architectural correctness | High | Medium | N/A |

## Constraints

1. **Layering**: L1 packages cannot depend on L2. Linux-specific Swift code in iso-9945
   (L2) that extends `Kernel.*` types (L1) can move to linux-primitives (L1) without
   layering violations — it only uses L1 types.

2. **Namespace**: Files moving from iso-9945 to linux-primitives change namespace from
   `ISO_9945.Kernel.*` to `Linux.Kernel.*` (or just extend `Kernel.*` directly).
   Consumers that call these Linux-specific APIs need updated import/call sites.

3. **Existing pattern**: linux-primitives already extends `Kernel.*` types with Linux
   mechanisms (e.g., `Linux.Kernel.File.Rename` for renameat2, `Linux.Kernel.IO.Uring`
   for io_uring). The pattern is established.

4. **Header-only needs**: 9 iso-9945 files import `CLinuxShim` solely for header access
   (O_DIRECT, statfs, etc.). Once the Swift code using these moves to linux-primitives,
   the header access comes from `CLinuxKernelShim` (already there).

5. **Build infrastructure only**: C shim targets expose no Swift API surface. Moving
   them is invisible to consumers — only Package.swift and import statements change.

## Recommendation

**Status**: RECOMMENDATION

**Adopt Option A + Option C combined.**

### End State

```
kernel-primitives          → Zero C shim targets (platform-agnostic)

iso-9945                   → CISO9945Shim (POSIX-standard C interop only):
                              swift_ioctl_tiocgwinsz  (ioctl is variadic)
                              swift_RTLD_DEFAULT      (C macro)
                              swift_RTLD_NEXT         (C macro)
                              swift_shm_open          (variadic on Darwin)
                            → CPOSIXProcessShim (already there):
                              swift_fork, wait macros, execve, posix_spawn

linux-primitives           → CLinuxKernelShim (already there, unchanged)
                            → Receives Linux-specific Swift files from iso-9945:
                              copy_file_range, ficlone, pipe2, getrandom, renameat2

darwin-primitives          → CDarwinKernelShim (already there, unchanged)
                            → Receives Darwin-specific Swift files from iso-9945:
                              clonefile

iso-9899                   → CISO9899* (already there, unchanged)
```

### Migration Order

| Step | Action | Packages touched |
|------|--------|-----------------|
| 1 | Create `CISO9945Shim` in iso-9945 with the 4 needed POSIX wrappers | iso-9945 |
| 2 | Update iso-9945 POSIX files to use `CISO9945Shim` (and direct Darwin/Glibc calls for isatty/tcgetattr/tcsetattr) | iso-9945 |
| 3 | Move Linux-specific Swift files from iso-9945 to linux-primitives | iso-9945, linux-primitives |
| 4 | Move Darwin-specific Swift file (clonefile) from iso-9945 to darwin-primitives | iso-9945, darwin-primitives |
| 5 | Remove `CLinuxShim` imports from remaining iso-9945 files (header-only imports become unnecessary once Swift code moves) | iso-9945 |
| 6 | Delete `CDarwinShim`, `CLinuxShim`, `CPosixShim` from kernel-primitives | kernel-primitives |

### Unnecessary Shims to Eliminate

| Shim | Replacement | Where |
|------|-------------|-------|
| `swift_isatty(fd)` | `Darwin.isatty(fd)` / `Glibc.isatty(fd)` | iso-9945 |
| `swift_tcgetattr(fd, t)` | `Darwin.tcgetattr(fd, t)` / `Glibc.tcgetattr(fd, t)` | iso-9945 |
| `swift_tcsetattr(fd, a, t)` | `Darwin.tcsetattr(fd, a, t)` / `Glibc.tcsetattr(fd, a, t)` | iso-9945 |

## References

- Console mechanism relocation (this session): `swift-primitives/HANDOFF-kernel-primitives-platform-conditionals.md`
- Five-layer architecture: `swift-institute/Documentation.docc/Five Layer Architecture.md`
- iso-9899 C shim pattern: `swift-iso/swift-iso-9899/Sources/CISO9899*/`
