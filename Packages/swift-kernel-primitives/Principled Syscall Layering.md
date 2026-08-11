# Principled System Call Layering in Swift: Separating Standards, Primitives, and Abstractions
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: RECOMMENDATION
---
-->

## Abstract

Modern systems programming in Swift requires careful management of platform dependencies, particularly when interfacing with operating system kernels through system calls. This paper presents a principled architectural restructuring that separates three distinct concerns currently conflated in a single package: ISO standard representations, platform-specific primitives, and cross-platform abstractions. We propose migrating POSIX system calls to a dedicated ISO 9945 standards package, retaining only semantic types in the primitives layer, and introducing a foundations-level unified API. This separation enables faithful standard representation, eliminates inappropriate cross-layer dependencies, and provides clear ownership boundaries for syscall implementations. We present a phased migration strategy that maintains build stability throughout the transition.

## 1. Introduction

The Swift ecosystem for systems programming has evolved organically, resulting in architectural decisions that conflate distinct concerns. A representative case is `swift-kernel-primitives`, a package that currently serves three roles simultaneously:

1. **Type definitions**: Semantic wrappers like `Kernel.Descriptor`, error enumerations, and option types
2. **POSIX syscall bindings**: Direct calls to `close()`, `read()`, `write()`, and other POSIX functions
3. **Cross-platform unification**: Abstracting differences between POSIX and Windows APIs

This conflation violates the principle of single responsibility and creates architectural tension when attempting to establish canonical locations for standard interfaces. Specifically, if ISO 9945 (POSIX) syscalls are to have a canonical representation—analogous to how ISO 9899 (C) functions are represented in `swift-iso-9899`—they cannot simultaneously reside in a "primitives" package that is conceptually below the standards layer.

This paper addresses the question: *How should Swift systems packages be structured to provide faithful standard representations while enabling cross-platform abstractions?*

Our contribution is a three-tier architecture that cleanly separates:
- **Standards packages** (ISO 9899, ISO 9945): Canonical, faithful representations of international standards
- **Primitives packages**: Platform-specific types and APIs not covered by standards
- **Foundations packages**: Cross-platform semantic APIs that normalize platform differences

## 2. Background and Motivation

### 2.1 The Current Architecture

The existing `swift-kernel-primitives` package contains 224 Swift source files organized around the `Kernel.*` namespace. Analysis reveals:

- **54 files** contain platform imports (`Darwin`, `Glibc`, `WinSDK`) and syscall invocations
- **170 files** contain only type definitions with no platform dependencies

The syscall-containing files directly import platform modules:

```swift
#if os(macOS) || os(iOS) || ...
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

extension Kernel.Close {
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        try Kernel.Syscall.require(Darwin.close(descriptor.rawValue), ...)
    }
}
```

This pattern repeats across file operations (`open`, `read`, `write`), directory operations (`mkdir`, `rmdir`), memory operations (`mmap`, `munmap`), and socket operations (`socket`, `bind`, `listen`).

### 2.2 The Layering Problem

The project maintains a conceptual layering model:

```
primitives ← standards ← foundations
```

Where lower layers should not depend on higher layers. However, the current architecture violates this model because:

1. **Primitives contain standards**: POSIX syscalls (standardized in ISO 9945) are implemented in the primitives layer
2. **No canonical POSIX location**: Unlike ISO 9899 which has `swift-iso-9899`, POSIX has no dedicated standards package
3. **Cross-platform abstraction in primitives**: The `Kernel.*` unified API conceptually belongs in foundations, not primitives

### 2.3 The ISO 9945 Gap

ISO/IEC 9945, also known as POSIX (Portable Operating System Interface), standardizes:

- System calls: `open`, `close`, `read`, `write`, `fork`, `exec`, etc.
- Library functions: `opendir`, `readdir`, `pthread_create`, etc.
- Shell and utilities: Command-line interface standards

The project already has `swift-iso-9899` for C standard library functions with the namespace `ISO_9899.*`. The absence of an analogous `swift-iso-9945` with namespace `ISO_9945.*` creates an architectural gap where POSIX functions lack a canonical home.

## 3. Design Principles

We establish the following principles to guide the restructuring:

**P1. Canonical Standard Locations**: Each international standard (ISO 9899, ISO 9945) has exactly one package that provides its canonical Swift representation. No other package may implement these interfaces directly.

**P2. Layer Isolation**: Primitives packages contain only types and platform-specific (non-standardized) APIs. Standards packages contain standard interfaces. Foundations packages contain cross-platform abstractions.

**P3. Dependency Direction**: Dependencies flow upward: primitives → standards → foundations. Lower layers never depend on higher layers.

**P4. Type Unification**: Semantic types shared across platforms (e.g., `Kernel.Descriptor`) are defined once in the primitives layer and used by all higher layers.

**P5. No Platform Leakage in Primitives**: After restructuring, the primitives package must not import `Darwin`, `Glibc`, `Musl`, or `WinSDK`. These imports are permitted only in standards packages (as an exception for implementing standard interfaces) and platform-specific packages.

## 4. Proposed Architecture

### 4.1 Three-Tier Structure

```
┌─────────────────────────────────────────────────────────────┐
│              swift-foundations/swift-kernel                  │
│         Unified cross-platform API (Kernel.*)               │
│    Normalization, error mapping, semantic operations        │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        ↓ (POSIX)                             ↓ (Windows)
┌────────────────────────┐           ┌────────────────────────┐
│  swift-standards/      │           │  swift-primitives/     │
│  swift-iso-9945        │           │  swift-windows-primitives │
│                        │           │                        │
│  ISO_9945.Unistd.*     │           │  Windows.Kernel.*      │
│  ISO_9945.Fcntl.*      │           │  (CloseHandle, etc.)   │
│  ISO_9945.Sys.Stat.*   │           │                        │
│  ISO_9945.Sys.Mman.*   │           │                        │
│  ISO_9945.Pthread.*    │           │                        │
└────────────────────────┘           └────────────────────────┘
                │                              │
        ┌───────┴──────────────────────────────┘
        ↓
┌────────────────────────────────────────────────────────────┐
│            swift-primitives/swift-kernel-primitives         │
│                                                             │
│     Kernel.Descriptor    Kernel.Error    Kernel.Outcome    │
│     Kernel.File.Open.Options    Kernel.Memory.Map.Flags    │
│                                                             │
│              (Types only — NO platform imports)             │
└────────────────────────────────────────────────────────────┘
```

### 4.2 Package Responsibilities

**swift-kernel-primitives** (restructured):
- Semantic type definitions only
- No `import Darwin`, `import Glibc`, `import WinSDK`
- Exports: `Kernel.Descriptor`, `Kernel.Error`, option types, error enumerations
- Build constraint: CI enforces absence of platform imports

**swift-iso-9945** (new):
- Canonical POSIX syscall implementations
- May import `Darwin`, `Glibc`, `Musl` (standards exception)
- Namespace: `ISO_9945.*` organized by POSIX header
- Depends on: `swift-kernel-primitives` (for shared types), `swift-iso-9899` (for errno)

**swift-windows-primitives** (enhanced):
- Windows kernel API implementations
- Imports `WinSDK`
- Namespace: `Windows.*`
- Depends on: `swift-kernel-primitives` (for shared types)

**swift-kernel** (new, in foundations):
- Unified cross-platform `Kernel.*` operational API
- Delegates to `ISO_9945` on POSIX, `Windows` on Windows
- Performs normalization and semantic error mapping
- Depends on: `swift-kernel-primitives`, `swift-iso-9945` (POSIX), `swift-windows-primitives` (Windows)

### 4.3 Namespace Design

The ISO 9945 package follows POSIX header organization:

| POSIX Header | Swift Namespace | Example Functions |
|--------------|-----------------|-------------------|
| `<unistd.h>` | `ISO_9945.Unistd` | `close`, `read`, `write`, `lseek`, `dup`, `pipe`, `fork` |
| `<fcntl.h>` | `ISO_9945.Fcntl` | `open`, `fcntl`, `openat` |
| `<sys/stat.h>` | `ISO_9945.Sys.Stat` | `stat`, `fstat`, `chmod`, `mkdir` |
| `<sys/mman.h>` | `ISO_9945.Sys.Mman` | `mmap`, `munmap`, `mprotect`, `shm_open` |
| `<sys/socket.h>` | `ISO_9945.Sys.Socket` | `socket`, `bind`, `listen`, `accept`, `connect` |
| `<pthread.h>` | `ISO_9945.Pthread` | `pthread_create`, `pthread_join`, `pthread_mutex_*` |
| `<dirent.h>` | `ISO_9945.Dirent` | `opendir`, `readdir`, `closedir` |
| `<time.h>` | `ISO_9945.Time` | `clock_gettime`, `nanosleep` |

This organization provides:
- **Discoverability**: Developers familiar with POSIX headers find functions in expected locations
- **Faithfulness**: The Swift API mirrors the standard's organization
- **Isolation**: Changes to one header's functions don't affect others

### 4.4 Type Boundary Decisions

A critical design decision is where type boundaries occur:

**Option A: Raw types at ISO_9945 boundary**
```swift
// ISO_9945 uses raw Int32 file descriptors
extension ISO_9945.Unistd {
    public static func close(_ fd: Int32) throws(ISO_9945.Error)
}

// swift-kernel wraps in semantic type
extension Kernel.Close {
    public static func close(_ descriptor: Kernel.Descriptor) throws(Kernel.Close.Error) {
        try ISO_9945.Unistd.close(descriptor.rawValue)
    }
}
```

**Option B: Shared types at ISO_9945 boundary**
```swift
// ISO_9945 accepts Kernel.Descriptor directly
extension ISO_9945.Unistd {
    public static func close(_ descriptor: Kernel.Descriptor) throws(ISO_9945.Error)
}
```

We recommend **Option B** with the following rationale:

1. **Single type definition**: `Kernel.Descriptor` is defined once in primitives
2. **No conversion overhead**: Callers don't convert between type representations
3. **Consistent semantics**: The descriptor abstraction applies uniformly
4. **Permitted dependency**: Standards may depend on types-only primitives (P3 allows upward flow)

This requires permitting `swift-iso-9945` to depend on `swift-kernel-primitives`, which is acceptable because primitives contains only types, not implementations.

## 5. Error Handling Architecture

### 5.1 Errno Reuse

POSIX syscalls report errors via `errno`, which is defined in the C standard (ISO 9899), not POSIX. Our architecture reuses the existing `ISO_9899.Errno` type:

```swift
// swift-iso-9945 depends on swift-iso-9899 for errno
import ISO_9899

extension ISO_9945 {
    public struct Error: Swift.Error {
        public let errno: ISO_9899.Errno
        public let syscall: StaticString
    }
}
```

This avoids duplicate errno definitions and maintains the principle that each concept has one canonical location.

### 5.2 Typed Throws

All syscall wrappers use Swift's typed throws:

```swift
extension ISO_9945.Unistd {
    @inlinable
    public static func close(_ descriptor: Kernel.Descriptor) throws(ISO_9945.Error) {
        // ...
    }
}
```

The foundations layer may define richer error types with semantic meaning:

```swift
extension Kernel.Close {
    public enum Error: Swift.Error {
        case invalidDescriptor
        case interruptedBySignal
        case ioError(underlying: ISO_9945.Error)
    }
}
```

## 6. Migration Strategy

### 6.1 Phased Approach

The migration proceeds in six phases, each maintaining build stability:

**Phase 0: Inventory** (completed)
- Categorize all 224 files as TYPES (170) or OPS (54)
- Document syscall → POSIX header mapping
- Identify platform-specific files (eventfd, clonefile)

**Phase 1: Create ISO_9945 Skeleton**
- New package `swift-standards/swift-iso-9945`
- Minimal surface: `close`, `read`, `write`, `lseek`, `open`
- Validates architecture before full migration

**Phase 2: Extract Windows Syscalls**
- Move Windows-specific implementations to `swift-windows-primitives`
- Ensures Windows syscall ownership is correct

**Phase 3: Convert Primitives to Types-Only**
- Move remaining POSIX ops to `swift-iso-9945`
- Add CI lint: forbid platform imports in `swift-kernel-primitives`
- Move platform-specific ops to respective packages (linux, darwin)

**Phase 4: Create swift-kernel (Foundations)**
- New package `swift-foundations/swift-kernel`
- Recreate `Kernel.*` operational API
- Delegates to ISO_9945 (POSIX) or Windows primitives

**Phase 5: Compatibility Period**
- Deprecated typealiases for types (not operations)
- Migration guide for downstream packages

**Phase 6: Enforcement**
- CI rules forbid direct Darwin/Glibc imports outside allowed packages
- Remove compatibility shims after transition period

### 6.2 Dependency Graph Evolution

**Before Migration:**
```
swift-kernel-primitives
├── imports Darwin/Glibc/WinSDK
├── defines Kernel.* types
└── implements Kernel.* operations
```

**After Migration:**
```
swift-kernel (foundations)
├── depends on swift-iso-9945 (POSIX)
├── depends on swift-windows-primitives (Windows)
├── depends on swift-kernel-primitives (types)
└── implements unified Kernel.* API

swift-iso-9945 (standards)
├── imports Darwin/Glibc/Musl
├── depends on swift-kernel-primitives (types)
├── depends on swift-iso-9899 (errno)
└── implements ISO_9945.* POSIX surface

swift-kernel-primitives (primitives)
├── NO platform imports
└── defines Kernel.* types only
```

## 7. Platform-Specific Considerations

### 7.1 Non-POSIX APIs

Some current `swift-kernel-primitives` functionality is not POSIX-standardized:

| API | Platform | Destination |
|-----|----------|-------------|
| `eventfd()` | Linux | swift-linux-primitives |
| `clonefile()` | Darwin | swift-darwin-primitives |
| `io_uring` | Linux | swift-linux-primitives |
| `kqueue` | Darwin/BSD | swift-darwin-primitives |
| Console APIs | Windows | swift-windows-primitives |

These move to platform-specific packages, not ISO_9945.

### 7.2 POSIX Extensions

Some platforms extend POSIX with additional flags or functions:

```swift
// Linux-specific O_DIRECT flag
#if os(Linux)
extension ISO_9945.Fcntl.OpenFlags {
    public static let direct: Self = ...
}
#endif
```

These extensions are permitted in ISO_9945 with platform guards, as they represent platform-specific POSIX extensions rather than wholly non-standard APIs.

### 7.3 Windows Considerations

Windows does not implement POSIX (WSL notwithstanding). The architecture handles this by:

1. **No ISO_9945 on Windows**: The package is unavailable on Windows builds
2. **Windows primitives parallel structure**: `Windows.Kernel.*` mirrors `ISO_9945.*` conceptually
3. **Unification in foundations**: `swift-kernel` provides the cross-platform `Kernel.*` API

```swift
// swift-kernel (foundations)
extension Kernel.Close {
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        #if os(Windows)
        try Windows.Kernel.closeHandle(descriptor.handle)
        #else
        try ISO_9945.Unistd.close(descriptor)
        #endif
    }
}
```

## 8. Verification and Enforcement

### 8.1 Build-Time Verification

The restructured architecture is enforced through CI:

```yaml
# Forbid platform imports in swift-kernel-primitives
- name: Check primitives imports
  run: |
    if grep -r "import Darwin\|import Glibc\|import WinSDK" \
       swift-kernel-primitives/Sources/; then
      echo "ERROR: Platform imports forbidden in primitives"
      exit 1
    fi
```

### 8.2 Dependency Verification

Package manifests encode the layering:

```swift
// swift-iso-9945/Package.swift
dependencies: [
    .package(path: "../swift-iso-9899"),           // errno
    .package(path: "../swift-kernel-primitives"),  // types
]

// swift-kernel/Package.swift
dependencies: [
    .package(path: "../swift-kernel-primitives"),  // types
    .package(path: "../swift-iso-9945"),           // POSIX (non-Windows)
    .package(path: "../swift-windows-primitives"), // Windows
]
```

Swift Package Manager enforces acyclicity, preventing dependency inversions.

## 9. Related Work

### 9.1 Rust's Approach

Rust's `libc` crate provides raw FFI bindings to platform C libraries, while `nix` provides safe Rust wrappers for POSIX APIs. This two-layer approach is analogous to our ISO_9945 (raw-ish bindings) and swift-kernel (safe abstractions) separation.

### 9.2 Go's syscall Packages

Go separates `syscall` (deprecated, low-level) from `golang.org/x/sys` (platform-specific) and standard library packages (`os`, `net`). The standard library provides cross-platform abstractions similar to our foundations layer.

### 9.3 Swift System

Apple's `swift-system` package provides a similar layered approach with `SystemPackage` for low-level file descriptor operations. Our architecture is compatible with and could potentially interoperate with swift-system.

## 10. Conclusion

We have presented a principled restructuring of Swift systems packages that:

1. **Establishes ISO 9945 as the canonical POSIX location**: Parallel to ISO 9899 for C
2. **Converts primitives to types-only**: Eliminating inappropriate syscall implementations
3. **Introduces a foundations-level unified API**: Cross-platform `Kernel.*` in the correct layer
4. **Maintains build stability**: Phased migration with compatibility shims

The key insight is that "primitives" should mean foundational types, not foundational implementations. Syscall implementations belong in standards packages (for standardized interfaces) or platform packages (for non-standard APIs). Cross-platform abstraction belongs in foundations.

This restructuring enables:
- **Faithful standard representation**: ISO_9945 mirrors POSIX structure
- **Clear ownership**: Each syscall has exactly one implementation location
- **Correct layering**: Dependencies flow from primitives through standards to foundations
- **Platform isolation**: Platform imports are confined to appropriate packages

The phased migration strategy ensures downstream packages can adopt changes incrementally while the ecosystem transitions to the principled architecture.

## References

1. ISO/IEC 9899:2018. *Programming languages — C*.
2. ISO/IEC 9945:2009. *Information technology — Portable Operating System Interface (POSIX)*.
3. IEEE Std 1003.1-2017. *Standard for Information Technology — Portable Operating System Interface (POSIX)*.
4. The Open Group Base Specifications Issue 7, 2018 edition.
5. Swift Evolution. *SE-0413: Typed throws*.
6. Swift Evolution. *SE-0390: Noncopyable structs and enums*.
7. Apple Inc. *swift-system: Idiomatic, low-level interfaces to system calls*.
8. The Rust Community. *nix: Rust friendly bindings to *nix APIs*.

## Appendix A: File Classification

### A.1 OPS Files (54) — Require Migration

Core I/O: `Kernel.Close.swift`, `Kernel.IO.Read.swift`, `Kernel.IO.Write.swift`, `Kernel.Seek.swift`, `Kernel.Dup.swift`, `Kernel.Pipe.swift`, `Kernel.Sync.swift`

File Operations: `Kernel.File.Open.swift`, `Kernel.File.Control.swift`, `Kernel.File.Stats.Get.swift`, `Kernel.File.Chmod.swift`, `Kernel.File.Chown.swift`, `Kernel.File.Utimensat.swift`, `Kernel.File.Clone.swift`, `Kernel.File.Direct.swift`, `Kernel.File.System.Stats.swift`, `Kernel.File.Rename.swift`

Directory Operations: `Kernel.Directory.swift`, `Kernel.Directory.Working.swift`, `Kernel.Mkdir.swift`, `Kernel.Rmdir.swift`, `Kernel.Unlink.swift`, `Kernel.Rename.swift`, `Kernel.Link.swift`, `Kernel.Symlink.swift`, `Kernel.Path.Canonical.swift`

Memory Operations: `Kernel.Memory.Map.swift`, `Kernel.Memory.Map.Anonymous.swift`, `Kernel.Memory.Map.File.swift`, `Kernel.Memory.Shared.swift`, `Kernel.Lock.swift`

Socket Operations: `Kernel.Socket.swift`, `Kernel.Socket.Shutdown.swift`, `Kernel.Socket.Backlog.swift`

Thread Operations: `Kernel.Thread.swift`, `Kernel.Thread.Handle.swift`

Other: `Kernel.Environment.swift`, `Kernel.Clock.Continuous.swift`, `Kernel.Clock.Suspending.swift`, `Kernel.Time.swift`, `Kernel.Event.Descriptor.swift`, `Kernel.Console.Mode+Get.swift`, `Kernel.Console.Mode+Set.swift`, `Kernel.Error.swift`, `Kernel.Error.Code.swift`, `Kernel.Syscall.swift`, `Kernel.Copy.Clone.swift`, `Kernel.Random.swift`

### A.2 TYPES Files (170) — Remain in Primitives

All error types (`*.Error.swift`), option types (`*.Options.swift`, `*.Mode.swift`, `*.Flags.swift`), value types (`Kernel.Descriptor.swift`, `Kernel.Device.swift`, `Kernel.Inode.swift`), and namespace containers.

## Appendix B: POSIX Header to Namespace Mapping

| POSIX Header | Swift Namespace | Primary Functions |
|--------------|-----------------|-------------------|
| `<unistd.h>` | `ISO_9945.Unistd` | close, read, write, lseek, dup, dup2, pipe, fork, exec*, chdir, getcwd, rmdir, unlink, link, symlink, readlink, chown, fchown, access, isatty, sysconf |
| `<fcntl.h>` | `ISO_9945.Fcntl` | open, openat, creat, fcntl |
| `<sys/stat.h>` | `ISO_9945.Sys.Stat` | stat, fstat, lstat, fstatat, chmod, fchmod, mkdir, mkdirat, mkfifo, mknod, umask, futimens, utimensat |
| `<sys/mman.h>` | `ISO_9945.Sys.Mman` | mmap, munmap, mprotect, msync, mlock, munlock, mlockall, munlockall, shm_open, shm_unlink |
| `<sys/socket.h>` | `ISO_9945.Sys.Socket` | socket, bind, listen, accept, connect, send, recv, sendto, recvfrom, shutdown, getsockopt, setsockopt, getpeername, getsockname |
| `<sys/select.h>` | `ISO_9945.Sys.Select` | select, pselect, FD_SET, FD_CLR, FD_ISSET, FD_ZERO |
| `<sys/wait.h>` | `ISO_9945.Sys.Wait` | wait, waitpid, waitid |
| `<sys/resource.h>` | `ISO_9945.Sys.Resource` | getrlimit, setrlimit, getrusage |
| `<sys/time.h>` | `ISO_9945.Sys.Time` | gettimeofday, settimeofday, utimes |
| `<sys/uio.h>` | `ISO_9945.Sys.Uio` | readv, writev |
| `<pthread.h>` | `ISO_9945.Pthread` | pthread_create, pthread_join, pthread_detach, pthread_exit, pthread_self, pthread_equal, pthread_mutex_*, pthread_cond_*, pthread_rwlock_*, pthread_key_*, pthread_once |
| `<dirent.h>` | `ISO_9945.Dirent` | opendir, fdopendir, readdir, readdir_r, rewinddir, closedir, dirfd |
| `<termios.h>` | `ISO_9945.Termios` | tcgetattr, tcsetattr, tcsendbreak, tcdrain, tcflush, tcflow, cfgetispeed, cfgetospeed, cfsetispeed, cfsetospeed |
| `<signal.h>` | `ISO_9945.Signal` | kill, raise, sigaction, sigprocmask, sigpending, sigsuspend, sigwait |
| `<time.h>` | `ISO_9945.Time` | clock_gettime, clock_settime, clock_getres, nanosleep, timer_create, timer_delete, timer_settime, timer_gettime |
| `<poll.h>` | `ISO_9945.Poll` | poll, ppoll |
| `<dlfcn.h>` | `ISO_9945.Dlfcn` | dlopen, dlclose, dlsym, dlerror |
| `<semaphore.h>` | `ISO_9945.Semaphore` | sem_open, sem_close, sem_unlink, sem_wait, sem_trywait, sem_post, sem_getvalue |
| `<aio.h>` | `ISO_9945.Aio` | aio_read, aio_write, aio_error, aio_return, aio_cancel, aio_suspend, lio_listio |
| `<mqueue.h>` | `ISO_9945.Mqueue` | mq_open, mq_close, mq_unlink, mq_send, mq_receive, mq_setattr, mq_getattr |
