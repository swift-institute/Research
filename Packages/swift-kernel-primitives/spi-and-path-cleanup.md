# @_spi(Syscall) and Path Primitives Cleanup Analysis

Date: 2026-04-10

## @_spi(Syscall) Analysis

### File Count

**93 files** in `swift-iso-9945/Sources/` use `@_spi(Syscall)`:
- 12 are `exports.swift` files (one per target, used for `@_spi(Syscall) @_exported public import`)
- **81 are implementation files** that each carry their own per-file `@_spi(Syscall) import` lines

Every implementation file that touches `_rawValue` on `Kernel.Descriptor`, `Kernel.Socket.Descriptor`, `Kernel.Termios.Attributes`, error `init(code:)` SPI initializers, or similar must repeat the import. The most common pattern is:

```swift
@_spi(Syscall) import Kernel_File_Primitives
```

`Kernel_Descriptor_Primitives` alone appears in all 81 implementation files.

### What @_spi(Syscall) Protects

The SPI surface across L1 kernel primitives consists of:

| Target | SPI Members | Purpose |
|--------|-------------|---------|
| Kernel Descriptor Primitives | `init(_rawValue:)`, `var _rawValue` | Raw fd/HANDLE construction and extraction |
| Kernel Socket Primitives | `init(_rawValue:)`, `var _rawValue` | Raw socket fd construction and extraction |
| Kernel Terminal Primitives | `init(_rawValue:)`, `var _rawValue` on `Termios.Attributes`; `set` methods | Raw termios struct access |
| Kernel File Primitives | `init(code:)` on `Open.Error`, `Clone.Error`, `Copy.Error`, `Handle.Error` | Error construction from platform error codes |
| Kernel Environment Primitives | `init(...)` on `Entry` | Raw entry construction |
| Kernel Completion Primitives | `_rawValue` on `Submission.Address`, `Event.Result`, `Event.Options` | io_uring/kqueue completion ring access |
| Kernel Event Primitives | `_rawValue` on `Event.ID` | Raw event identifier |

The pattern is consistent: SPI guards the "break glass" boundary between typed Swift wrappers and raw platform integers. This is exactly the syscall layer's privilege.

### Why Per-File Import is Necessary

`@_spi` is **per-file** in Swift, by design. The `@_spi(Syscall) @_exported public import` in `exports.swift` serves a different purpose: it re-exports the SPI surface to downstream modules that import this target with `@_spi(Syscall)`. It does NOT propagate SPI visibility to sibling `.swift` files within the same target. Each source file must independently opt in.

This is verified by the codebase: the `ISO 9945 Kernel File` target has `exports.swift` containing `@_spi(Syscall) @_exported public import Kernel_Descriptor_Primitives`, yet every implementation file in that target (`IO.Read.swift`, `File.Open.swift`, etc.) still carries its own `@_spi(Syscall) import Kernel_Descriptor_Primitives`.

> **Warning — implementation lesson (burned hours):** The `@_exported public import` in `exports.swift` re-exports SPI to *downstream modules* that import this target with `@_spi(Syscall)`. It does **NOT** grant SPI access to sibling `.swift` files within the same target. This is not obvious — you might expect that if `exports.swift` imports `Kernel_Descriptor_Primitives` with `@_spi(Syscall)`, then `IO.Read.swift` in the same target would see `_rawValue`. It does not. Each file is an independent compilation unit for SPI purposes. This was discovered empirically during the iso-9945 modularization and caused significant debugging time before the per-file requirement was understood.

### Design Options Evaluated

**Option A: Reduce the SPI surface (fewer things behind SPI)**

Move `_rawValue` from `@_spi(Syscall)` to `package` access. This would eliminate the per-file import ceremony entirely -- `package` members are visible to all files in the same package without any import annotation.

Problem: `package` access is same-package only. `Kernel_Descriptor_Primitives` is in `swift-primitives` and `ISO_9945_*` is in `swift-iso-9945` -- they are different packages. So `package` cannot replace `@_spi` here. The existing `package var _raw: Raw` is only accessible within the L1 superrepo itself (used by `Kernel Completion Primitives` and `Kernel Socket Primitives` internally).

**Option B: Add a non-SPI closure-based accessor (e.g., `withUnsafeDescriptor`)**

```swift
// Hypothetical non-SPI API on Kernel.Descriptor:
public borrowing func withUnsafeDescriptor<R>(_ body: (Int32) throws(E) -> R) throws(E) -> R
```

This would let L2 call syscalls without SPI. But it has a fundamental flaw: the closure receives the raw value, which is exactly what SPI guards. A closure wrapper is cosmetically different but provides the same escape hatch. It would also prevent `_rawValue` access in non-closure contexts (like passing to C functions that need the fd as a direct argument, which is the majority of syscall sites).

Additionally, many syscall sites need both reading `_rawValue` AND constructing a new `Kernel.Descriptor(_rawValue: result)` from the return value. A read-only closure would not cover the construction side.

**Option C: Per-file opt-in is the correct design**

`@_spi` exists to mark "you know what you're doing" escape hatches. Per-file opt-in means:
1. Every file that touches raw descriptors explicitly declares that intent
2. Files that don't need raw access don't accidentally get it
3. The boundary is auditable: `grep "@_spi(Syscall)"` instantly identifies all syscall-boundary code
4. Adding a new file that needs raw access forces the author to consciously add the import

The 81-file burden is a **feature, not a bug**. It documents the exact blast radius of the raw descriptor boundary.

### Recommendation: Keep Per-File @_spi(Syscall)

**Verdict: Option C -- per-file opt-in is correct.**

Rationale:
1. **SPI is working as designed.** The per-file ceremony is Swift's intended mechanism for controlled access to implementation details across package boundaries.
2. **The burden is proportional to the risk.** Every file that reaches into `_rawValue` is performing unsafe platform interop. The import annotation is a trivial cost relative to the code it gates.
3. **Auditability.** A single grep identifies all 81 files that form the syscall boundary in iso-9945. This is a maintenance advantage, not a burden.
4. **No viable alternatives.** `package` does not cross package boundaries. Closure wrappers are cosmetic and would not cover the construction case. Removing SPI entirely would expose raw descriptors to all downstream consumers, violating the encapsulation intent.
5. **Precedent.** The same pattern is used by L3 (`swift-io`) with 35 `@_spi(Syscall) import Kernel` lines, and by `swift-windows-standard` at L2. The pattern scales and is consistent across the ecosystem.

The only ergonomic improvement possible would be reducing the number of distinct SPI imports per file (some files import 2-3 `@_spi` targets). This happens naturally as modularization stabilizes -- each target's `exports.swift` chains SPI re-exports upward, so a file in `ISO 9945 Kernel File` that imports `Kernel_File_Primitives` with SPI gets SPI on its transitive exports too.

---

## Path_Primitives vs Kernel_Path_Primitives

### What Each Provides

**`Path_Primitives`** (separate package: `swift-path-primitives`)

A platform-agnostic, domain-independent path primitive:
- `Path` -- owned, ~Copyable, null-terminated contiguous memory (`Memory.Contiguous<String.Char>`)
- `Path.Char` -- platform character type (UInt8 on POSIX, UInt16 on Windows)
- `Path.View` -- non-escapable borrowed view (~Copyable, ~Escapable)
- `Path.Protocol` -- decomposition protocol (parent, component, appending)
- `Path.Resolution` -- namespace with `Error` enum (notFound, exists, isDirectory, etc.)
- `Path.Canonical` -- namespace
- `Path.String` -- string conversion namespace
- `Path.ConversionError` -- interior NUL detection
- `Tagged<Tag, Path>` extensions -- full API forwarding for phantom-tagged paths

Source files: 8 files in `/Users/coen/Developer/swift-primitives/swift-path-primitives/Sources/Path Primitives/`

**`Kernel_Path_Primitives`** (target in `swift-kernel-primitives`)

A thin kernel-domain binding layer:
- `Kernel.Path` = `Tagged<Kernel, Path_Primitives.Path>` (a typealias)
- `Path.Canonical.Error` -- kernel-domain error mapping (wraps `Path.Resolution.Error`, `Kernel.Permission.Error`, `Kernel.Error`)
- `Path.Resolution.Error.init(code:)` -- maps `Kernel.Error.Code` to semantic resolution errors

Source files: 4 files in `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Path Primitives/`

The `exports.swift` in Kernel Path Primitives contains:
```swift
@_exported public import Path_Primitives
```

So importing `Kernel_Path_Primitives` automatically provides all of `Path_Primitives`.

### Consumer Analysis

**Direct `import Path_Primitives`:**
- 1 test file: `swift-path-primitives/Tests/Path Primitives Tests/PathTests.swift`
- 1 documentation reference: `swift-institute/Skills/platform/SKILL.md`

No production source files outside of `swift-path-primitives` itself import `Path_Primitives` directly.

**Direct `import Kernel_Path_Primitives`:**
- 161 files across 8 repositories (iso-9945, swift-kernel, swift-darwin, swift-linux, swift-linux-standard, swift-windows-standard, swift-paths, kernel-primitives itself)

All production consumers use `Path_Primitives` exclusively through the `Kernel_Path_Primitives` re-export.

### Consolidation Analysis

**Arguments for consolidation (merge Path.Char into Kernel.Path):**
1. Zero independent production consumers of `Path_Primitives`
2. Would eliminate one package and reduce the dependency graph
3. `Path` is inherently a kernel/OS concept -- there is no meaningful "non-kernel path"

**Arguments against consolidation (keep separate):**
1. **Tier separation.** `Path_Primitives` sits at a lower tier than `Kernel_Path_Primitives`. Path is a general data structure (null-terminated, owned string buffer with platform char type). Kernel is a domain qualifier. The split follows the same pattern as `String_Primitives` + `Kernel_String_Primitives`.
2. **Tagged pattern.** `Kernel.Path` is `Tagged<Kernel, Path>`. The entire `Tagged+Path.swift` extension layer in `Path_Primitives` enables other domains to create their own tagged paths (e.g., a hypothetical `HTTP.Path = Tagged<HTTP, Path>`). Consolidation would destroy this generality.
3. **`Path.Protocol` is domain-agnostic.** The `parent`/`component`/`appending` decomposition protocol is defined at the `Path` level and conformed to by platform packages. This protocol does not depend on kernel concepts.
4. **Foundation-free design.** `Path_Primitives` depends only on `String_Primitives`, `Memory_Primitives_Core`, and `Tagged_Primitives` -- all tier-0/1 packages. `Kernel_Path_Primitives` adds `Kernel_Primitives_Core`, `Kernel_Error_Primitives`, and `Kernel_Permission_Primitives`. These are different dependency tiers.
5. **Windows path representation.** If Windows paths (UInt16/UTF-16) are ever needed outside the kernel domain (e.g., COM interfaces, registry paths), the generic `Path` type would be the right building block.

### Recommendation: Keep Separate

**Verdict: Do not consolidate.**

`Path_Primitives` having zero independent production consumers today does not mean the separation is wrong. The separation encodes a real architectural distinction:

- `Path` is a **data structure**: an owned, null-terminated, platform-char buffer with a view type and a decomposition protocol.
- `Kernel.Path` is a **domain binding**: `Tagged<Kernel, Path>` with kernel-specific error mapping.

This follows the same pattern as `String_Primitives` (the data structure) vs `Kernel_String_Primitives` (the kernel domain binding). Consolidating Path but not String would be inconsistent.

The lack of independent consumers is expected at this stage -- the first domain to use paths is the kernel. If the ecosystem grows to include non-kernel path consumers (Windows COM, virtual filesystem layers, etc.), the separation is already in place. The cost of maintaining the separation is negligible (4 files in Kernel Path Primitives, 8 files in Path Primitives).
