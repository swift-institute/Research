# Platform Compliance Audit

---
- **Status**: IN_PROGRESS
- **Tier**: 2 (cross-package, precedent-setting)
- **Created**: 2026-03-19
- **Scope**: Ecosystem-wide — swift-primitives (L1), swift-standards (L2), swift-foundations (L3)
- **Rules audited**: [PLAT-ARCH-001–010], [PATTERN-001], [PATTERN-004a], [PATTERN-005]
---

## Summary

Ecosystem-wide inventory of compliance with the `/platform` skill across all three superrepos. The audit covers every `.swift` source file and C header outside the designated platform stack packages.

**Result (revised after [PLAT-ARCH-008a] Domain Authority Exception)**: 64 files initially flagged across 20 packages. After applying the domain authority exception, **12 true violations** remain across 7 packages. Zero violations in swift-standards.

| Severity | Count (files) | Description |
|----------|---------------|-------------|
| CRITICAL | 8 | Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` in consumer packages |
| HIGH | 0 | *(All 52 reclassified — see below)* |
| MEDIUM | 1 | Shared C header with platform conditionals (should be per-platform shims) |
| LOW | 3 | Inherently platform-tied code (SwiftUI integration, linker-model sections) |
| ACCEPTED | 47 | Domain authority conditionals per [PLAT-ARCH-008a] (import Kernel, domain strategy, irreducible) |
| INVESTIGATE | 5 | Possibly unnecessary guards or import-hierarchy questions requiring verification |

**Root cause of 8 CRITICAL violations**: Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` bypassing the platform stack. Fix: switch to `import Kernel` (or extend Kernel where APIs are missing).

**[PLAT-ARCH-008a] reclassification**: 47 files previously flagged as HIGH are domain authority conditionals — packages like swift-io, swift-paths, swift-file-system, swift-memory own the domain concepts that vary by platform and compose Kernel types via `import Kernel`. These conditionals are accepted per the new [PLAT-ARCH-008a] exception.

## Scope and Exclusions

### Searched

All `.swift` files in `Sources/` directories and `.h` files across:
- `/Users/coen/Developer/swift-primitives/` (Layer 1)
- `/Users/coen/Developer/swift-standards/` (Layer 2)
- `/Users/coen/Developer/swift-foundations/` (Layer 3)

### Excluded (platform stack — conditionals expected by design)

| Package | Superrepo | Reason |
|---------|-----------|--------|
| swift-kernel-primitives | swift-primitives | L1 shared platform primitives |
| swift-darwin-primitives | swift-primitives | L1 Darwin-specific primitives |
| swift-linux-primitives | swift-primitives | L1 Linux-specific primitives |
| swift-windows-primitives | swift-primitives | L1 Windows-specific primitives |
| swift-iso-9945 | swift-standards | L2 POSIX specification |
| swift-darwin | swift-foundations | L3 Darwin foundations |
| swift-linux | swift-foundations | L3 Linux foundations |
| swift-windows | swift-foundations | L3 Windows foundations |
| swift-kernel | swift-foundations | L3 unified kernel |

Also excluded: `Tests/`, `Experiments/` directories.

### Not flagged (compliant per skill)

- `#if !hasFeature(Embedded)` guards (Conditional Compilation Foresight)
- `.when(platforms: [...])` in Package.swift ([PATTERN-004])
- Comments mentioning platforms
- `@_exported` re-exports within the platform stack

## Methodology

### Search patterns

1. **Platform conditional compilation**: `#if canImport(Darwin)`, `#if canImport(Glibc)`, `#if canImport(Musl)`, `#if canImport(WinSDK)`, `#if os(Linux)`, `#if os(macOS)`, `#if os(Windows)`, `#if os(iOS)`, `#if os(visionOS)`
2. **Direct platform module imports**: `import Darwin`, `import Glibc`, `import Musl`, `import WinSDK`, `import CRT`
3. **C header conditionals**: `#if defined(__APPLE__)`, `#if defined(__linux__)`, `#ifdef _WIN32`, `#if defined(_WIN32)`

### Assessment criteria

Each violation assessed against:
- [PLAT-ARCH-002]: Is platform code placed in the platform stack?
- [PLAT-ARCH-008]: Do consumer packages import Kernel instead of platform modules?
- [PATTERN-001]: Are C shims per-platform or shared with conditionals?
- [PATTERN-004a]: Is `canImport` used for platform identity instead of `os()`?

---

## Findings — CRITICAL

Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` in non-platform packages. These bypass the platform stack entirely and create hard dependencies on platform-specific modules.

### C-1: swift-system-primitives — System.Processor.swift

| Field | Value |
|-------|-------|
| **Package** | swift-system-primitives (L1) |
| **File:Line** | `swift-primitives/swift-system-primitives/Sources/System Primitives/System.Processor.swift:45-53` |
| **Rule violated** | [PLAT-ARCH-008], [PLAT-ARCH-002] |
| **What it does** | Imports Darwin/Glibc/Musl/WinSDK to call `sysconf(_SC_NPROCESSORS_ONLN)` and `GetSystemInfo()` for CPU count |
| **Severity** | CRITICAL |
| **Fix** | Move processor count query to swift-kernel-primitives as `Kernel.System.Processor.Count` accessor; consumer uses `import Kernel_Primitives` |
| **Blocked by** | Missing `Kernel.System.Processor` abstraction in swift-kernel-primitives |

### C-2: swift-system-primitives — System.Page.swift

| Field | Value |
|-------|-------|
| **Package** | swift-system-primitives (L1) |
| **File:Line** | `swift-primitives/swift-system-primitives/Sources/System Primitives/System.Page.swift:57-64` |
| **Rule violated** | [PLAT-ARCH-008], [PLAT-ARCH-002] |
| **What it does** | Imports Darwin/Glibc/Musl/WinSDK to call `sysconf(_SC_PAGESIZE)` and `GetSystemInfo()` for page size |
| **Severity** | CRITICAL |
| **Fix** | Move page size query to swift-kernel-primitives as `Kernel.System.Page.Size` accessor |
| **Blocked by** | Missing `Kernel.System.Page` abstraction in swift-kernel-primitives |

### C-3: swift-io — IO.Blocking.Lane.Abandoning.swift

| Field | Value |
|-------|-------|
| **Package** | swift-io (L3) |
| **File:Line** | `swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.Lane.Abandoning.swift:10-14` |
| **Rule violated** | [PLAT-ARCH-008] |
| **What it does** | Imports Darwin/Glibc for pthread thread management (abandoning hung operations) |
| **Severity** | CRITICAL |
| **Fix** | Replace `import Darwin`/`import Glibc` with `import Kernel`; use `Kernel.Thread` APIs |
| **Blocked by** | Verify `Kernel.Thread` exposes the needed pthread operations |

### C-4: swift-io — IO.Blocking.Lane.Abandoning.Worker.swift

| Field | Value |
|-------|-------|
| **Package** | swift-io (L3) |
| **File:Line** | `swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.Lane.Abandoning.Worker.swift:11-14` |
| **Rule violated** | [PLAT-ARCH-008] |
| **What it does** | Imports Darwin/Glibc for pthread worker thread creation |
| **Severity** | CRITICAL |
| **Fix** | Replace with `import Kernel`; use `Kernel.Thread` APIs |
| **Blocked by** | Same as C-3 |

### C-5: swift-console — Console.Capability+Detect.swift

| Field | Value |
|-------|-------|
| **Package** | swift-console (L3) |
| **File:Line** | `swift-foundations/swift-console/Sources/Console/Console.Capability+Detect.swift:16-21` |
| **Rule violated** | [PLAT-ARCH-008] |
| **What it does** | Imports Darwin/Glibc/CRT for `isatty()`, `getenv()`, terminal capability detection |
| **Severity** | CRITICAL |
| **Fix** | Replace with `import Kernel`; use `Kernel.Terminal.isInteractive` or similar |
| **Blocked by** | Missing `Kernel.Terminal.isInteractive` and `Kernel.Environment.get` in swift-kernel |

### C-6: swift-console — Console.Input.Reader.swift

| Field | Value |
|-------|-------|
| **Package** | swift-console (L3) |
| **File:Line** | `swift-foundations/swift-console/Sources/Console/Console.Input.Reader.swift:14-19` |
| **Rule violated** | [PLAT-ARCH-008] |
| **What it does** | Imports Darwin/Glibc/Musl for POSIX read operations on stdin |
| **Severity** | CRITICAL |
| **Fix** | Replace with `import Kernel`; use Kernel file descriptor read operations |
| **Blocked by** | Verify `Kernel.Descriptor` read operations are sufficient |

### C-7: swift-source — Source.Loader.swift

| Field | Value |
|-------|-------|
| **Package** | swift-source (L3) |
| **File:Line** | `swift-foundations/swift-source/Sources/Source/Source.Loader.swift:6-12` |
| **Rule violated** | [PLAT-ARCH-008] |
| **What it does** | Imports Darwin/Glibc/Musl for `open(2)`, `fstat(2)`, `read(2)` — POSIX file loading |
| **Severity** | CRITICAL |
| **Fix** | Replace with `import Kernel`; Kernel already provides file descriptor operations |
| **Blocked by** | None — Kernel should already have these operations |

### C-8: swift-posix — POSIX.Kernel.Glob.Match.swift

| Field | Value |
|-------|-------|
| **Package** | swift-posix (L3) |
| **File:Line** | `swift-foundations/swift-posix/Sources/POSIX Kernel/POSIX.Kernel.Glob.Match.swift:14-20` |
| **Rule violated** | [PLAT-ARCH-008], [PLAT-ARCH-007] |
| **What it does** | Imports Darwin/Glibc/Musl for POSIX `glob()` implementation; extends `Kernel_Primitives.Kernel.Glob` |
| **Severity** | CRITICAL |
| **Fix** | Move glob implementation to swift-iso-9945 (L2, POSIX specification) per [PLAT-ARCH-007]; consumer uses `import Kernel` |
| **Blocked by** | Missing `Kernel.Glob` implementation in swift-iso-9945 |

---

## Findings — HIGH

Platform conditionals (`#if os(...)`, `#if canImport(...)`) in non-platform consumer code. The code works cross-platform but leaks platform knowledge that belongs in the platform stack.

### swift-io (14 HIGH files)

The IO event loop architecture implements kqueue/epoll/IOCP dispatching directly in swift-io instead of through swift-kernel. The files import `Kernel` correctly but gate entire files or blocks behind platform conditionals.

| # | File | Lines | What it does | Fix |
|---|------|-------|--------------|-----|
| H-1 | `IO Events/IO.Event.Driver+Platform.swift` | 21-29 | `#if canImport(Darwin)` → kqueue, `#if canImport(Glibc)` → epoll dispatch | Move to swift-kernel as unified event driver factory |
| H-2 | `IO Events/IO.Event.Driver+Witness.Key.swift` | 11-13 | Platform-conditional Witness.Key default | Unify in swift-kernel |
| H-3 | `IO Events/IO.Event.Driver.swift` | 190, 217 | Platform-conditional kqueue/epoll factory methods | Move factories to swift-kernel |
| H-4 | `IO Events/IO.Event.Driver.Handle.swift` | 30, 42, 62 | `#if os(Windows)` for HANDLE vs fd storage | Abstract in Kernel.Descriptor |
| H-5 | `IO Events/IO.Event.Queue.Operations.swift` | 8 | Entire file gated `#if canImport(Darwin)` — kqueue operations | Move to swift-darwin or swift-kernel |
| H-6 | `IO Events/IO.Event.Poll.Operations.swift` | 8 | Entire file gated `#if canImport(Glibc)` — epoll operations | Move to swift-linux or swift-kernel |
| H-7 | `IO/IO.Backend.swift` | 71, 76, 96 | `#if os(Linux)`, `#if os(Windows)` backend selection | Unify in swift-kernel |
| H-8 | `IO Completions/IO.Completion.Driver+Witness.Key.swift` | 11, 15 | Platform-conditional completion driver key | Unify in swift-kernel |
| H-9 | `IO Completions/IO.Completion.IOUring.swift` | 8 | Entire file gated `#if os(Linux)` — io_uring | Move to swift-linux or swift-kernel |
| H-10 | `IO Completions/IO.Completion.IOUring.Ring.swift` | 8 | Entire file gated `#if os(Linux)` — io_uring ring | Move to swift-linux or swift-kernel |
| H-11 | `IO Completions/IO.Completion.IOCP.swift` | 8 | Entire file gated `#if os(Windows)` — IOCP | Move to swift-windows or swift-kernel |
| H-12 | `IO Completions/IO.Completion.IOCP.Header.swift` | 8 | Entire file gated `#if os(Windows)` | Move to swift-windows or swift-kernel |
| H-13 | `IO Completions/IO.Completion.IOCP.Registry.swift` | 8 | Entire file gated `#if os(Windows)` | Move to swift-windows or swift-kernel |
| H-14 | `IO Completions/IO.Completion.Driver.Handle.swift` | 33-90 | `#if os(Windows)` / `#if os(Linux)` for handle storage | Abstract in Kernel |
| H-15 | `IO Completions/IO.Completion.Queue.swift` | 529-531 | `#if os(Windows)` / `#if os(Linux)` dispatch | Unify in swift-kernel |
| H-16 | `IO Completions/IO.Completion.Queue.shared.swift` | 70-72 | `#if os(Windows)` / `#if os(Linux)` dispatch | Unify in swift-kernel |

**Blocked by**: swift-kernel needs a unified event driver API that abstracts kqueue/epoll/IOCP. This is the largest single remediation item — it requires designing `Kernel.Event.Driver` as a cross-platform abstraction in swift-kernel, then refactoring swift-io to use it. See also `Research/zero-copy-event-pipeline.md` (H-3 from the swift-io deep audit, status: DESIGN NEEDED).

### swift-file-system (8 HIGH files)

All violations are `#if os(Windows)` branching for Windows path separators, ownership semantics, and API differences.

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-17 | `File.System.Metadata.Ownership.swift` | 51, 70, 105, 134 | Windows vs POSIX ownership model |
| H-18 | `File.System.Metadata.Permissions.swift` | 86, 105, 140, 167 | Windows vs POSIX permission model |
| H-19 | `File.System.Link.Read.Target.swift` | 44, 64 | Windows vs POSIX link target reading |
| H-20 | `File.System.Delete.swift` | 52, 75 | Windows vs POSIX file deletion |
| H-21 | `File.Path.swift` | 70, 144 | Windows vs POSIX path handling |
| H-22 | `File.Name.swift` | 199 | Windows path separator in name validation |
| H-23 | `File.System.Parent.Check.swift` | 41 | Windows vs POSIX parent directory check |
| H-24 | `File.Descriptor.swift` | 62 | Windows HANDLE vs POSIX fd |

**Fix**: Abstract path separator, ownership, and permissions into Kernel-level types. `Kernel.Path.Separator`, `Kernel.File.Ownership`, `Kernel.File.Permissions` should handle the platform differences.
**Blocked by**: Missing path/ownership/permissions unification in swift-kernel.

### swift-paths (6 HIGH files)

All violations are `#if os(Windows)` for Windows path separator (`\` vs `/`).

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-25 | `Path.Introspection.swift` | 32, 142, 157 | Windows separator detection in path analysis |
| H-26 | `Path.Navigation.swift` | 33, 81, 134, 183, 248 | Windows separator in path navigation (parent, join, etc.) |
| H-27 | `Path.Component.swift` | 40, 136 | Windows separator in component splitting |
| H-28 | `Path.swift` | 103, 160, 227 | Windows separator in path construction |
| H-29 | `Path.Component.Stem.swift` | 46 | Windows separator awareness |
| H-30 | `Path.Component.Extension.swift` | 50 | Windows separator awareness |

**Fix**: Same as swift-file-system — unify path separator in Kernel. `Kernel.Path.Separator` constant or `Kernel.Path.isSeparator(_:)` would eliminate all conditionals.
**Blocked by**: Missing `Kernel.Path.Separator` in swift-kernel.

### swift-memory (4 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-31 | `Memory.Map+Init.swift` | 216, 386, 433 | `#if os(Windows)` / `#if os(Linux)` for memory-mapped file init |
| H-32 | `Memory.Map+Operations.swift` | 79, 225 | `#if os(Windows)` for memory map operations |
| H-33 | `Memory.Page.Lock.swift` | 77 | `#if os(Windows)` for page locking |
| H-34 | `Memory.Shared.swift` | 229 | `#if os(Windows)` for shared memory |

**Fix**: Memory mapping should be unified through Kernel. `Kernel.Memory.Map` already exists in the platform stack — verify swift-memory uses it.
**Blocked by**: Verify Kernel.Memory.Map covers all operations swift-memory needs.

### swift-console (2 HIGH files, beyond the 2 CRITICAL)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-35 | `exports.swift` | 15 | `#if os(macOS) || ... || os(Linux)` gating POSIX imports |
| H-36 | `Console.Input.swift` | 17 | `#if os(macOS) || ... || os(Linux)` gating functionality |

**Fix**: Use `import Kernel` unconditionally; Kernel handles platform dispatch.

### swift-loader (3 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-37 | `exports.swift` | 14-16 | Platform-conditional imports of Darwin_Kernel / Linux_Kernel |
| H-38 | `Loader.Section.swift` | 14-49 | `#if canImport(Darwin)` / `#if os(Linux)` for Mach-O vs ELF section enumeration |
| H-39 | `Loader.Symbol.swift` | 14-46 | `#if canImport(Darwin)` / `#if os(Linux)` / `#if os(Windows)` for symbol lookup |

**Fix**: Use `import Kernel`; section enumeration and symbol lookup should be unified through Kernel or use a dedicated loader abstraction in swift-kernel.
**Blocked by**: Missing unified `Kernel.Loader` API for section/symbol access.

### swift-random (1 HIGH file)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-40 | `Exports.swift` | 6-12 | Conditionally re-exports `Darwin_Kernel`, `Linux_Kernel`, `Windows_Kernel` — duplicates the swift-kernel unification pattern |

**Fix**: Replace with `@_exported public import Kernel`. Since swift-kernel already re-exports all platform kernel modules, swift-random's conditional re-exports are redundant.
**Blocked by**: None — `import Kernel` should already provide everything.

### swift-strings (2 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-41 | `Swift.String+Primitives.swift` | 20, 44, 73, 110 | `#if os(Windows)` for UTF-16 vs UTF-8 string conversion |
| H-42 | `ISO_9899.String+Primitives.swift` | 62 | `#if os(Windows)` in documentation block |

**Fix**: Use `String.Char` (from swift-string-primitives) which already encapsulates the platform character width.
**Blocked by**: Verify `String.Char` provides sufficient abstraction.

### swift-posix (1 HIGH file, beyond the 1 CRITICAL)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-43 | `POSIX.Kernel.File.Flush.swift` | 52, 73 | `#if os(Linux)` for `fdatasync`, `#if canImport(Darwin)` for `F_FULLFSYNC` |

**Fix**: Move flush semantics to swift-iso-9945 (POSIX) and swift-darwin-primitives (F_FULLFSYNC); consumer uses Kernel.
**Blocked by**: Missing `Kernel.File.Flush` unification.

### swift-environment (1 HIGH file)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-44 | `Environment.Read.swift` | 51 | `#if os(Windows)` for environment variable reading |

**Fix**: Use `import Kernel`; environment variable access should be in Kernel.
**Blocked by**: Missing `Kernel.Environment` in swift-kernel.

### swift-numerics (1 HIGH file)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-45 | `Numeric.Math.SignGamma.swift` | 9, 27 | `#if canImport(Darwin) \|\| canImport(Glibc) \|\| canImport(Musl)` guards on pure arithmetic |

**Fix**: Investigate whether the guards are necessary. If `signGamma` is pure arithmetic, remove the guards. If it depends on `lgamma`, gate only the lgamma-dependent path.
**Blocked by**: None.

### swift-numeric-primitives (3 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-46 | `Numeric.Math.swift` | 110, 210, 218, 308 | `canImport(Darwin\|\|Glibc\|\|Musl)` for lgamma; `os(iOS\|macOS\|...)` for Float16 |
| H-47 | `Numeric.Math.Accessor.swift` | 152, 300, 313, 449 | Same patterns as Math.swift |
| H-48 | `Numeric.Transcendental+Conformances.swift` | 75 | `os(iOS\|macOS\|...)` for Float16 conformance |

**Fix for lgamma**: Move lgamma availability into a Kernel-level math abstraction or accept the conditional (lgamma is genuinely unavailable on Windows).
**Fix for Float16**: Float16 availability is a hardware capability, not a platform identity. Use `#if arch(arm64)` or `#if swift(>=N)` if possible, or accept the `#if os(...)` guard as the best available mechanism.
**Blocked by**: Swift lacks a `#if hasFeature(Float16)` capability check — `#if os(...)` is the only way to express Float16 availability today.

### swift-string-primitives (2 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-49 | `String.Char.swift` | 22 | `#if os(Windows)` → `UInt16`, else `UInt8` for native character width |
| H-50 | `String.swift` | 99 | `#if os(Windows)` for ASCII literal initialization |

**Fix**: This is a fundamental vocabulary type. Could move to swift-kernel-primitives as `Kernel.Char` or accept it where it is (string-primitives is the natural home for character types). The conditional is inherent to the Windows UTF-16 vs POSIX UTF-8 difference.
**Blocked by**: Design decision — should `Kernel.Char` exist, or should string-primitives own this?

### swift-terminal-primitives (2 HIGH files)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-51 | `Terminal.Mode.Raw.Token.swift` | 44, 48 | `#if !os(Windows)` for POSIX termios vs Windows console mode |
| H-52 | `Terminal.Stream.swift` | 31 | `#if os(Windows)` for Windows console handle mapping |

**Fix**: Move terminal raw mode token and stream mapping to the platform stack. `Kernel.Terminal` should abstract these differences.
**Blocked by**: Missing `Kernel.Terminal.Mode.Raw` abstraction.

### swift-path-primitives (1 HIGH file)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-53 | `Path.String.swift` | 668 | `#if os(Windows)` for Windows path character handling |

**Fix**: Abstract through `String.Char` or a Kernel path separator constant.
**Blocked by**: Same as swift-paths/swift-file-system path separator issue.

### swift-loader-primitives (1 HIGH file)

| # | File | Lines | What it does |
|---|------|-------|--------------|
| H-54 | `Loader.Section.Name.swift` | 58, 87 | `#if os(macOS\|iOS\|...)` for Mach-O vs ELF section names |

**Fix**: Section names are inherently tied to the binary format (Mach-O/ELF/PE). Could move to the platform stack, or accept as inherent to the loader domain.
**Blocked by**: Design decision — are binary format section names platform knowledge or loader vocabulary?

---

## Findings — MEDIUM

### M-1: swift-numeric-primitives — Shared C shim header

| Field | Value |
|-------|-------|
| **Package** | swift-numeric-primitives (L1) |
| **File:Line** | `swift-primitives/swift-numeric-primitives/Sources/_Shims/include/shims.h:114, 141, 262, 275, 417` |
| **Rule violated** | [PATTERN-001] |
| **What it does** | Single shared C header with `#if defined(_WIN32)` and `#if !defined(_WIN32)` conditionals for hypotf and lgamma availability |
| **Severity** | MEDIUM |
| **Fix** | Split into per-platform shim files: `_DarwinShims/`, `_LinuxShims/`, `_WindowsShims/` with platform-specific implementations |
| **Blocked by** | None — pure restructuring |

---

## Findings — LOW

### L-1: swift-html-rendering — SwiftUI ViewRepresentable

| Field | Value |
|-------|-------|
| **Package** | swift-html-rendering (L3) |
| **File:Line** | `swift-foundations/swift-html-rendering/Sources/HTML Renderable/HTML.Document+ViewRepresentable.swift:2, 38, 55` |
| **Rule violated** | [PLAT-ARCH-008] (technically) |
| **What it does** | `#if os(macOS)` for NSViewRepresentable, `#if os(iOS)` for UIViewRepresentable — SwiftUI/AppKit/UIKit integration |
| **Severity** | LOW |
| **Fix** | This is inherently platform-specific (AppKit vs UIKit). Consider moving to a separate platform-specific integration module, or accept the conditional. |
| **Blocked by** | None — SwiftUI integration is fundamentally platform-conditional |

### L-2: swift-testing — Testing.Discovery.swift

| Field | Value |
|-------|-------|
| **Package** | swift-testing (L3) |
| **File:Line** | `swift-foundations/swift-testing/Sources/Testing/Testing.Discovery.swift:41` |
| **Rule violated** | [PLAT-ARCH-008] (technically) |
| **What it does** | `#if canImport(Darwin)` fallback for older Darwin binaries using `__DATA` instead of `__DATA_CONST` section |
| **Severity** | LOW |
| **Fix** | Backward-compatibility shim for older Darwin. Could move section name mapping to swift-loader-primitives. Remove when minimum deployment target advances. |
| **Blocked by** | None |

### L-3: swift-testing — Macro.Shared.swift

| Field | Value |
|-------|-------|
| **Package** | swift-testing (L3) |
| **File:Line** | `swift-foundations/swift-testing/Sources/Testing Macros Implementation/Macro.Shared.swift:53-57` |
| **Rule violated** | [PLAT-ARCH-008] (technically) |
| **What it does** | `@_section` attribute names differ by platform (Mach-O/ELF/PE linking model) |
| **Severity** | LOW |
| **Fix** | Section name constants could come from swift-loader-primitives `Loader.Section.Name`. Already an L1 type — just not used here yet. |
| **Blocked by** | None — just wire up the existing type |

---

## Summary Statistics

### By severity

| Severity | Files | Packages |
|----------|-------|----------|
| CRITICAL | 8 | 5 |
| HIGH | 52 | 15 |
| MEDIUM | 1 | 1 |
| LOW | 3 | 2 |
| **Total** | **64** | **20** |

### By superrepo

| Superrepo | Layer | Violations | Packages affected |
|-----------|-------|------------|-------------------|
| swift-primitives | L1 | 12 files | 6 (system, numeric, string, path, terminal, loader) |
| swift-standards | L2 | 0 files | 0 |
| swift-foundations | L3 | 52 files | 14 |

### By rule

| Rule | Description | Violation count |
|------|-------------|----------------|
| [PLAT-ARCH-008] | Consumer import rule | 60 files |
| [PLAT-ARCH-002] | Misplaced platform code | 8 files |
| [PLAT-ARCH-007] | POSIX code belongs in ISO 9945 | 1 file |
| [PATTERN-001] | Shared C header with conditionals | 1 file |

### By violation pattern

| Pattern | Files |
|---------|-------|
| `#if os(Windows)` | 32 |
| `#if canImport(Darwin)` | 18 |
| `#if canImport(Glibc)` | 8 |
| `#if os(Linux)` | 8 |
| `import Darwin` (direct) | 7 |
| `import Glibc` (direct) | 7 |
| `import Musl` (direct) | 5 |
| `import WinSDK` / `import CRT` | 3 |
| `#if os(macOS\|iOS\|...)` | 5 |
| `#if canImport(Musl)` | 3 |
| `#if defined(_WIN32)` (C) | 1 |

### Top violating packages

| Package | Files | Severity breakdown |
|---------|-------|--------------------|
| swift-io | 18 | 2 CRITICAL, 16 HIGH |
| swift-file-system | 8 | 8 HIGH |
| swift-paths | 6 | 6 HIGH |
| swift-console | 4 | 2 CRITICAL, 2 HIGH |
| swift-memory | 4 | 4 HIGH |
| swift-numeric-primitives | 4 | 3 HIGH, 1 MEDIUM |
| swift-loader | 3 | 3 HIGH |
| swift-system-primitives | 2 | 2 CRITICAL |
| swift-strings | 2 | 2 HIGH |
| swift-string-primitives | 2 | 2 HIGH |
| swift-terminal-primitives | 2 | 2 HIGH |
| swift-testing | 2 | 2 LOW |
| swift-posix | 2 | 1 CRITICAL, 1 HIGH |
| swift-source | 1 | 1 CRITICAL |
| swift-random | 1 | 1 HIGH |
| swift-numerics | 1 | 1 HIGH |
| swift-environment | 1 | 1 HIGH |
| swift-path-primitives | 1 | 1 HIGH |
| swift-loader-primitives | 1 | 1 HIGH |
| swift-html-rendering | 1 | 1 LOW |

---

## Remediation Plan

### Phase 1: Quick wins — no platform stack changes needed

These can be fixed immediately by switching to existing Kernel imports.

| Item | Package | Fix | Effort |
|------|---------|-----|--------|
| C-7 | swift-source | Replace `import Darwin/Glibc/Musl` with `import Kernel`; use Kernel file operations | Small |
| H-40 | swift-random | Replace conditional re-exports with `@_exported public import Kernel` | Trivial |
| H-45 | swift-numerics | Investigate if platform guards are necessary; remove if pure arithmetic | Small |
| L-3 | swift-testing | Use `Loader.Section.Name` constants from swift-loader-primitives | Small |

### Phase 2: Kernel vocabulary gaps — extend platform stack

These require adding missing abstractions to swift-kernel-primitives or swift-kernel.

| Gap | Affects | Where to add | Effort |
|-----|---------|--------------|--------|
| `Kernel.System.Processor.Count` | C-1, C-2 (swift-system-primitives) | swift-kernel-primitives | Small |
| `Kernel.System.Page.Size` | C-1, C-2 (swift-system-primitives) | swift-kernel-primitives | Small |
| `Kernel.Path.Separator` | H-17–30, H-53 (15 files) | swift-kernel-primitives | Small |
| `Kernel.Environment.get` | H-44 (swift-environment), C-5 (swift-console) | swift-kernel or swift-iso-9945 | Small |
| `Kernel.Terminal.isInteractive` | C-5, C-6, H-35–36 (swift-console) | swift-kernel or swift-iso-9945 | Small |
| `Kernel.File.Flush` unification | H-43 (swift-posix) | swift-kernel | Small |
| `Kernel.Glob` implementation | C-8 (swift-posix) | swift-iso-9945 | Medium |

### Phase 3: IO event driver unification — design needed

The largest remediation item. 16 files in swift-io have platform conditionals for kqueue/epoll/IOCP event loop dispatch. This requires designing a unified event driver API in swift-kernel.

| Item | Description | Effort |
|------|-------------|--------|
| Unified `Kernel.Event.Driver` | Cross-platform event driver in swift-kernel that selects kqueue/epoll/IOCP | Large (design needed) |
| Move IO.Event.Queue.Operations | Kqueue operations → swift-darwin or swift-kernel | Medium |
| Move IO.Event.Poll.Operations | Epoll operations → swift-linux or swift-kernel | Medium |
| Move IO.Completion.IOUring | io_uring → swift-linux or swift-kernel | Medium |
| Move IO.Completion.IOCP | IOCP → swift-windows or swift-kernel | Medium |
| Refactor IO.Blocking.Lane | Replace `import Darwin/Glibc` with `import Kernel` thread APIs | Small |

**Note**: This overlaps with the deferred H-3 (zero-copy event pipeline) from the swift-io deep audit. Coordinate design.

### Phase 4: Domain design decisions

These require explicit architectural discussion about where platform-conditional vocabulary types belong.

| Decision | Packages affected | Options |
|----------|-------------------|---------|
| Should `String.Char` (UTF-8/UTF-16) move to Kernel? | swift-string-primitives, swift-path-primitives, swift-strings | A: Move to Kernel. B: Keep in string-primitives (it's a string concept, not a kernel concept). |
| Should section names be loader vocabulary? | swift-loader-primitives, swift-testing | A: Accept in loader-primitives. B: Move to platform stack. |
| Should terminal raw mode move to Kernel? | swift-terminal-primitives | A: Move to Kernel. B: Keep in terminal-primitives with accepted conditional. |
| Should memory map operations unify through Kernel? | swift-memory | A: Verify Kernel.Memory.Map coverage. B: Extend Kernel if insufficient. |
| Float16 availability: accept `#if os(...)` or find alternative? | swift-numeric-primitives | A: Accept (no `#if hasFeature(Float16)` exists). B: Use `#if arch(arm64)` if precise enough. |

### Phase 5: C shim restructuring

| Item | Package | Fix | Effort |
|------|---------|-----|--------|
| M-1 | swift-numeric-primitives | Split `_Shims/include/shims.h` into per-platform shim files | Medium |

---

## Cross-References

- `/platform` skill — [PLAT-ARCH-*], [PATTERN-*] rules audited
- `Research/swift-io-deep-audit.md` — H-3 zero-copy event pipeline (DESIGN NEEDED)
- `Research/zero-copy-event-pipeline.md` — Event pipeline design
- `Research/system-kernel-system-boundary.md` — System vs Kernel.System namespace
- `Research/comparative-apple-swift-system-metrics.md` — Gap analysis for system info APIs
