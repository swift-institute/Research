# Embedded Swift

@Metadata {
    @TitleHeading("Swift Institute")
}

Patterns and constraints for writing Swift packages compatible with Embedded Swift.

> Note: Embedded Swift as a target is in development for the ecosystem (see the <doc:FAQ>). This article describes the patterns and toolchain mechanics that the ecosystem's Embedded work is tracking, drawn from upstream Embedded Swift itself. Package-level Embedded support will ship with the platform milestone.

## Overview

Embedded Swift is a language subset targeting baremetal and resource-constrained environments. Packages at the Primitives and Standards layers are designed to be compatible with Embedded Swift; Foundations packages are compatible where their dependencies allow.

This document covers how to compile for Embedded Swift, which concurrency features are available, and how to write dual-target code that works in both standard and Embedded builds.

---

## Quick reference

| Section | Focus |
|---------|-------|
| [Compilation](#Compilation) | Toolchain, flags, build commands |
| [Concurrency model](#Concurrency-model) | What works, what does not, and why |
| [Compatibility patterns](#Compatibility-patterns) | Writing dual-target code |

---

## Compilation

### Toolchain

Embedded Swift compilation requires a development snapshot toolchain. Release toolchains fail with:

```
error: module 'Swift' cannot be imported in embedded Swift mode
```

A typical invocation uses the snapshot toolchain's `swiftc` directly:

```bash
/path/to/swift-DEVELOPMENT-SNAPSHOT-<date>.xctoolchain/usr/bin/swiftc \
    -enable-experimental-feature Embedded ...
```

Embedded Swift is still experimental; release toolchains do not include the runtime stubs that Embedded mode needs. As of Swift 6.3, release toolchains remain unable to compile Embedded mode; tracking the current nightly is necessary for Embedded work.

---

### Required compiler flags

Embedded Swift compilation needs these flags at a minimum:

| Flag | Purpose |
|------|---------|
| `-enable-experimental-feature Embedded` | Enable Embedded mode |
| `-wmo` | Whole-module optimization (required) |
| `-parse-as-library` | Library code without a `main` entry point |
| `-package-name <name>` | Required if the code uses `package` access |

A complete invocation for a host build looks like:

```bash
swiftc -enable-experimental-feature Embedded -wmo -parse-as-library \
    -package-name MyPackage Sources/*.swift
```

---

### Cross-compilation

Cross-compiling for embedded targets uses architecture-specific flags. A representative ARM Cortex-M invocation:

```bash
swiftc -enable-experimental-feature Embedded -wmo \
    -target armv7em-none-none-eabi \
    -Osize \
    -Xfrontend -disable-stack-protector \
    Sources/*.swift
```

The `-Osize` flag optimizes for binary size. The `-disable-stack-protector` flag removes stack canaries, which are unavailable on baremetal.

---

## Concurrency model

### Three tiers of availability

Concurrency features fall into three categories in Embedded Swift:

| Tier | Behavior | Features |
|------|----------|----------|
| Fully available | Compiles and links | `Sendable`, `@Sendable`, `sending`, `nonisolated`, `actor` (synchronous use only) |
| Compile-only | Compiles, fails to link | `async` / `await`, `Task`, `AsyncSequence`, `#isolation` |
| Unavailable | Fails to compile | `@MainActor` |

Swift's concurrency type system is present in Embedded mode; the runtime (scheduler, task creation) is not.

---

### Compile-only features

Features in the compile-only tier produce linker errors referencing missing runtime symbols:

```
Undefined symbols for architecture arm64:
  "_swift_task_switch"
  "_swift_task_create"
  "_swift_task_asyncMainDrainQueue"
```

This boundary reflects the architectural split: type checking works, runtime dispatch does not. Libraries can define async API surfaces guarded with `#if !hasFeature(Embedded)`. The guards are about runtime availability, not language availability.

---

### The @MainActor exception

`@MainActor` fails at parse time with "unknown attribute", not at link time:

```swift
@MainActor
struct Data { }
// error: unknown attribute 'MainActor'
```

`MainActor` has platform semantics — main dispatch queue, main thread. Embedded systems have no standard "main execution context," and the attribute is therefore undefined. Custom global actors (`@MyGlobalActor`) do compile, though they still fail to link. The difference is that custom actors have no platform-specific meaning.

---

### Sendable as the Embedded story

The fully-available concurrency subset centers on `Sendable`:

- `Sendable` protocol conformance
- `@Sendable` closure annotation
- `sending` parameter modifier
- `@unchecked Sendable` escape hatch
- `nonisolated` function modifier
- `actor` keyword (synchronous use only)

Each of these is a compile-time annotation that informs the type checker. None requires runtime support. On Embedded systems this enables types designed for concurrent access without actual concurrent execution — suitable for interrupt contexts and event loops.

---

### Explicit concurrency import

Concurrency types (`Task`, `Actor`) require an explicit `import _Concurrency` in Embedded mode:

```swift
import _Concurrency  // Required in Embedded; implicit in standard Swift

actor Counter { ... }
```

Without the import, `Task` produces "cannot find 'Task' in scope." This asymmetry can trap developers porting async code to Embedded.

---

## Compatibility patterns

### Conditional compilation guards

Packages targeting Embedded Swift use `#if !hasFeature(Embedded)` around unavailable features:

```swift
#if !hasFeature(Embedded)
extension Tagged: Codable where RawValue: Codable { }
#endif

#if !hasFeature(Embedded)
public func fetchAsync() async throws -> Data { ... }
#endif
```

Features that typically need guards:

| Feature | Reason |
|---------|--------|
| `Codable` | Requires reflection |
| `CustomStringConvertible` | May require reflection |
| `async` functions | Runtime unavailable |
| Existentials (`any`) | Not supported |
| Foundation types | Not available |

---

### Sync alternatives

Libraries with async APIs provide sync alternatives for Embedded compatibility:

```swift
// Available everywhere
public func read(from descriptor: Descriptor) throws(IO.Error) -> Data

// Standard Swift only
#if !hasFeature(Embedded)
public func read(from descriptor: Descriptor) async throws(IO.Error) -> Data
#endif
```

`Sendable` annotations carry forward into Embedded builds. The async APIs disappear. What remains is type-safe data structures ready for manual concurrency coordination.

---

### Binary size as feedback

Embedded compilation should produce significantly smaller binaries than standard compilation. A 60–70% size reduction is a good signal that Embedded mode is working correctly:

| Target | Approximate size | Indicates |
|--------|------------------|-----------|
| macOS arm64 | ~22 KB | Full runtime metadata |
| ARM Cortex-M | ~6 KB | Embedded mode working |

The reduction comes from what Embedded mode removes: runtime metadata, reflection support, existential containers, and dynamic dispatch infrastructure.

---

## Interpreting compiler failures

Compiler crashes and error messages carry different implications in Embedded mode:

| Response | Indicates | Example |
|----------|-----------|---------|
| Error message | Intentional restriction | `@MainActor` — "unknown attribute" |
| Compiler crash | Incomplete implementation | `actor` + `await` — SIL-generation crash |

A crash during SIL generation suggests a feature is partially implemented and may work in future toolchains. Documentation is clearer when it distinguishes "not yet implemented" from "intentionally restricted."

