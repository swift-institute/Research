---
date: 2026-04-09
session_objective: Relocate platform-specific C shims and Swift code from kernel-primitives and iso-9945 to their correct architectural homes
packages:
  - swift-kernel-primitives
  - swift-linux-primitives
  - swift-darwin-primitives
  - swift-iso-9945
  - swift-terminal-primitives
status: pending
---

# C Shim Placement and Platform Code Separation

## What Happened

Started with a handoff investigating platform conditionals in kernel-primitives (220 files).
Identified 8 Console mechanism files as Windows-specific — deleted them (windows-primitives
already had the real implementation). Removed `CWindowsShim` (dead after Console removal).
Updated terminal-primitives consumer.

Then the user challenged: should the remaining C shims (CDarwinShim, CLinuxShim, CPosixShim)
also leave kernel-primitives? Investigation revealed all three were dead weight — no Swift code
in kernel-primitives called them. Platform packages already had identical copies.

Research document (`c-shim-placement-architecture.md`) established the end state:
- kernel-primitives: zero C shims (platform-agnostic)
- iso-9945: `CISO9945Shim` for genuine POSIX C interop only (ioctl, RTLD macros, shm_open)
- Platform packages receive platform-unique Swift code

Migration moved 5 Linux-specific Swift files from iso-9945 to linux-primitives, 4 Darwin-specific
files to darwin-primitives. Three vocabulary types (Options, Flags, Whence) were promoted from
iso-9945 to kernel-primitives so platform packages could extend them. Eliminated 3 unnecessary
shim wrappers (isatty, tcgetattr, tcsetattr — callable directly from Darwin/Glibc).

All packages build on macOS. `Linux Kernel Primitives` verified on Docker Linux (Swift 6.3).
Full swift-linux build blocked by pre-existing issues (ownership-primitives region isolation,
io_uring type mismatch).

## What Worked and What Didn't

**Worked well:**
- The iso-9899 C shim pattern was the perfect precedent — standards packages own their standard's C interop. Applying this to iso-9945 was clean.
- The user's challenges ("why would iso-9945 need Linux shims?!") forced correct architecture. Each pushback eliminated a wrong assumption.
- Research-first approach (formal document before implementation) prevented the repeated false starts.

**Didn't work well:**
- Repeatedly tried to put platform-specific code in iso-9945 ("just as internal helpers"), getting corrected each time. The mental model of "iso-9945 implements POSIX, POSIX needs platform calls" was correct, but "iso-9945 should contain platform-UNIQUE features" was wrong.
- Vocabulary type declarations being in iso-9945 rather than kernel-primitives caused cascading failures when platform packages tried to extend them. Each one (Options, Flags, Whence) was discovered only at build time.
- Docker builds were slow and fragile (xattr issues, broken symlinks, missing deps). Each iteration took 2-5 minutes.

## Patterns and Root Causes

**The vocabulary type problem is systematic.** iso-9945 declares many types (`Options`, `Flags`, `Whence`, likely `Descriptors`, `Access`, `Mode`, etc.) that are vocabulary — they define the shape of a concept without platform-specific implementation. These belong in kernel-primitives (L1) so both iso-9945 (L2) and platform packages (L1) can work with them. We moved three; there are likely more that will surface as platform packages gain more functionality.

**The POSIX vs platform-unique distinction is the key architectural principle.** iso-9945 owns POSIX-standard implementations (`open`, `read`, `write`, `pipe`, `mmap` — calling Darwin.open / Glibc.open is fine). Platform packages own extensions beyond POSIX (`O_DIRECT`, `FICLONE`, `renameat2`, `clonefile`, `F_NOCACHE`). The `#if canImport(Darwin)` in iso-9945 is correct when choosing which POSIX libc to call — wrong when implementing Darwin-unique features.

**C shim duplication was a code smell indicating misplacement.** kernel-primitives' shims were identical to platform packages' shims. Duplication between layers means something is in the wrong layer. The platform packages were the correct home all along.

## Action Items

- [ ] **[research]** Systematic inventory of vocabulary types declared in iso-9945 that should be in kernel-primitives — Options, Flags, Whence were found ad-hoc; a proactive sweep would find the rest before they block future platform package work
- [ ] **[skill]** primitives: Add guidance that vocabulary types (struct declarations with rawValue, OptionSets, RawRepresentable wrappers) MUST be declared in kernel-primitives, not in standards packages, so platform packages at the same layer can extend them
- [ ] **[package]** swift-ownership-primitives: Apply V9 fix (split Optional.take into Sendable/non-Sendable overloads) per HANDOFF investigation findings — blocks Docker Linux nightly builds
