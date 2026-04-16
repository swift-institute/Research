# Platform

@Metadata {
    @TitleHeading("Swift Institute")
}

Cross-platform Swift infrastructure — how the ecosystem achieves portability, and what is specific to each platform.

## Overview

The Swift Institute ecosystem is designed for cross-platform correctness. The same code compiles on Darwin and Linux today; Embedded Swift and Windows support are coming.

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux (glibc, musl) | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

---

## How cross-platform abstraction works

Platform code is organized into three conceptual levels:

```
Foundations    Unified cross-platform module — `import Kernel`
                     ↑
               Per-platform foundations extensions
                     ↑
Standards      Platform-specific kernel APIs (e.g. kqueue, epoll, IOCP)
               POSIX specification (shared by Darwin and Linux)
                     ↑
Primitives     Cross-platform syscall vocabulary
               CPU vocabulary (atomics, barriers, spin hints)
```

Consumer code writes one import:

```swift
import Kernel

// The right platform is wired automatically. No platform conditionals in consumer code.
```

Platform conditionals are concentrated at the top of the stack — in re-export files and `Package.swift` dependency conditions — so consumer code remains unconditional.

---

## Unified types

A single `Kernel.Descriptor` type represents file handles, socket handles, and OS resource handles across all supported platforms. It wraps the platform's native representation (`Int32` on POSIX systems, `HANDLE` on Windows) and exposes platform-specific veneers where raw access is needed.

Cross-platform code never sees the platform's native representation directly. Platform-specific code that needs raw access uses the appropriate veneer.

---

## Darwin

Supported. Darwin covers macOS, iOS, tvOS, watchOS, and visionOS.

The Darwin/XNU kernel surface — `kqueue`, mach ports, Mach-O loader, Darwin-specific memory and thread APIs — is modelled at the standards layer. Higher-level Darwin-specific composition (NUMA, entropy, thread affinity) lives at the foundations layer.

The POSIX surface is shared with Linux: code that targets POSIX works identically on both platforms.

---

## Linux

Supported. Targets glibc and musl C libraries.

The Linux kernel surface — `epoll`, `io_uring`, `futex`, `eventfd`, and Linux-specific syscalls — is modelled at the standards layer. Higher-level Linux-specific composition (NUMA via libnuma, thread affinity, cgroups integration) lives at the foundations layer.

The POSIX surface is shared with Darwin.

---

## Embedded Swift

Coming soon.

Embedded Swift is a language subset targeting baremetal and resource-constrained environments. Primitives and standards packages are designed for Embedded compatibility: no Foundation, no reflection, no existentials in public API, minimal standard-library dependencies.

Foundations packages that compose only Embedded-compatible dependencies are also Embedded-compatible. Packages using async runtimes, existentials, or features unavailable in Embedded mode are guarded with `#if !hasFeature(Embedded)`.

See <doc:Embedded-Swift> for the patterns and constraints involved.

---

## Windows

Coming soon. Windows support will follow the same pattern as Darwin and Linux.
