# swift-file-system Deep Audit

**Date**: 2026-03-19 (updated after Phase 3)
**Package**: swift-file-system (Layer 3 — Foundations)
**Location**: `/Users/coen/Developer/swift-foundations/swift-file-system/`
**Scope**: 47 source files in File System Primitives (5760 lines), 32 in File System (3533 lines), 65 test files
**Dependencies**: swift-kernel, swift-io, swift-environment, swift-paths, swift-strings, swift-ascii, swift-binary-primitives, swift-rfc-4648

---

## Executive Summary

swift-file-system is the oldest package in the ecosystem. It **works** — the architecture is sound, typed throws are used pervasively, and Kernel delegation is clean.

### Completed Work

**Phase 1 — Dead code removal** (committed as f2837b9, -1290 lines):
- Deleted 6 stubs, 2 dead utils, FTS walker, empty File.Path.swift (19 files removed)
- Removed swift-time-primitives dependency
- Removed `@_exported` for ASCII and RFC_4648
- Fixed H-6: fully-qualified module name collision resolved by deleting `File.System.Create.File` stub

**Phase 2 — Typed throws cleanup** (committed as f2837b9):
- fatalError("unreachable"): 6 → 0
- Result<> workarounds: 8 → 0
- Kernel.Path.scope closures: 6 → 0
- catch let error as: 14 → 5 (remaining are language limitations in Walk/Contents untyped throws callbacks)

**Upstream refactor** (committed as 299c7b8, dd4e4af):
- swift-paths replaced `withKernelPath` closures with direct `path.kernelPath` property access
- All 45 call sites migrated (-87 lines)

**Phase 3 — Consolidate duplicated code** (this session, -294 lines):
- Walk: 3 traversal implementations → 1. Deleted `_walk()` and `_walkCallbackThrowing()`. `callAsFunction` now delegates to `iterate()`. Throwing `iterate()` wraps non-throwing variant with error capture.
- Glob: 6 copy-pasted pattern construction blocks → 1 shared `_matchPaths`. All 6 variants (sync+async × 3) use the shared core. Async variants delegate to their sync counterpart via `IO.run`.
- Error mapping: Eliminated duplicate `_mapKernelOpenError` in Contents.Iterator by sharing `_mapKernelError` from Contents (made `internal`).
- IO.Closable: Added conformance to `File.Descriptor` (signature already matched).

### Remaining Issues

- **5 `catch let error as`**: All in Walk `_walkCallback` and Contents throwing `iterate`. Language limitation — the callback closures are untyped throws, so errors from recursive Walk calls or Contents iteration must be caught dynamically. Cannot be eliminated until Swift supports typed rethrows.
- **14 hand-rolled accessor structs**: Evaluated for Property<Tag, Base> migration. **Deferred** — these are clean Copyable structs wrapping `File.Path` with type-specific methods. Property migration would add a dependency for marginal savings (~5 lines per struct declaration) without structural improvement.
- **4 single-case error wrappers**: Evaluated for typealias replacement. **Deferred** — breaking public API change. The wrappers decouple the File System layer from Kernel error types, provide semantic accessors, and are extensively tested.

---

## Remaining Findings

### MEDIUM — M-1: Compound method/property names [API-NAME-002]

| Identifier | File | Should Be |
|------------|------|-----------|
| `iterateFiles(options:body:)` | `Walk.swift:168` | `iterate.files(options:body:)` |
| `iterateDirectories(options:body:)` | `Walk.swift:187` | `iterate.directories(options:body:)` |
| `isFile(at:)` | `File.System.Stat.swift` (FS) | Evaluate — reads naturally as bool |
| `isDirectory(at:)` | `File.System.Stat.swift` (FS) | Evaluate |
| `isSymlink(at:)` | `File.System.Stat.swift` (FS) | Evaluate |
| `lstatInfo(at:)` | `File.System.Stat.swift` (FSP) | `info(at:followSymlinks:)` |
| `seekToEnd()` | `File.Handle.swift` (FS) | `seek.toEnd()` |

**Assessment**: These are breaking API changes. `iterateFiles`/`iterateDirectories` could be renamed to `iterate.files`/`iterate.directories` using the Property pattern since Walk is already a namespace struct. The `isFile`/`isDirectory`/`isSymlink` read naturally as boolean predicates — standard Swift convention, not a violation. `lstatInfo` and `seekToEnd` are genuine violations.

---

### MEDIUM — M-2: Multiple type declarations per file [API-IMPL-005]

| File | Types Declared | Should Split |
|------|----------------|--------------|
| `File.Name.swift` | `Name`, `RawEncoding` | `File.Name.RawEncoding.swift` |
| `File.Directory.Contents.swift` | `Contents`, `Control` | `File.Directory.Contents.Control.swift` |
| `File.Directory.Contents.Iterator.swift` | `Iterator`, `IteratorHandle` | `File.Directory.Contents.IteratorHandle.swift` |
| `File.Directory.Walk.swift` | `Walk`, `InodeKey` | `File.Directory.Walk.InodeKey.swift` (internal) |
| `File.System.Create.swift` | `Create`, `Options` | `File.System.Create.Options.swift` |
| `File.System.Create.Directory.swift` | `Directory`, `Options`, `Error` | Split Options and Error |

---

### MEDIUM — M-3: Raw Int arithmetic where Kernel types exist [IMPL-002]

| File | Expression | Should Be |
|------|------------|-----------|
| `File.Handle.swift` | `totalWritten += written` | Use typed count |
| `File.System.Read.Full.swift` | `totalRead += bytesRead` | Use typed count |
| `File.System.Stat.swift` | `UInt32(stats.linkCount.rawValue.rawValue)` | rawValue chain — 2 levels |
| `File.System.Stat.swift` | `stats.size.rawValue`, `stats.uid.rawValue` | rawValue extraction for mapping |

---

### MEDIUM — M-9: File.Path._resolvingPOSIX does ad-hoc string manipulation

Uses `hasPrefix`, `lastIndex(of: "/")`, `removeLast()` instead of Paths APIs.

---

### MEDIUM — M-10: File.Handle._pwrite/_pwriteAll are package-internal but substantial

Positional write methods with ESPIPE fallback. Evaluate whether they should be consolidated into atomic write.

---

### MEDIUM — M-12: Walk.Options.onUndecodable uses closure instead of enum

Over-engineered. A `Undecodable.Policy` property would suffice for 99% of use cases. However, the closure pattern does work and provides maximum flexibility. Low priority.

---

### LOW — L-2: File lacks ExpressibleByStringLiteral conformance

Doc comment claims it; conformance missing.

---

### LOW — L-3: File.Handle.Open and File.Descriptor.Open are near-identical

~70% structural duplication. Could share implementation.

---

### LOW — L-5: Binary.Serializable conformances on enum types may be premature

On 5 types without documented consumers.

---

### LOW — L-6: Walk.Error and Contents.Error overlap

Both define `.pathNotFound`, `.permissionDenied`, `.notADirectory`. Walk maps Contents errors to its own type in `_walkCallback`. Could unify, but Walk.Error has additional cases (`.walkFailed`, `.undecodableEntry`) that Contents.Error doesn't need.

---

### LOW — L-7: File.Path.Property is a novel pattern not used elsewhere

Only 2 built-in properties. Consider moving to Paths.

---

## Resolved Findings

| ID | Finding | Resolution | Phase |
|----|---------|------------|-------|
| C-2 | fatalError("unreachable") workarounds (6 sites) | All eliminated | Phase 2 |
| C-3 | Result<T,E> workarounds (8 sites) | All eliminated | Phase 2 |
| C-4 | File.Handle.write error capture | Restructured in Phase 2 | Phase 2 |
| C-5 | Walk: 3 traversal implementations | Consolidated to 1 | Phase 3 |
| C-6 | Kernel.Path.scope closures (6 sites) | All replaced with `path.kernelPath` | Phase 2 |
| H-1 | File.Descriptor missing IO.Closable | Conformance added | Phase 3 |
| H-3 | Single-case error wrappers (4 types) | **Deferred** — breaking API change | — |
| H-4 | 14 hand-rolled accessor structs | **Deferred** — marginal benefit | — |
| H-5 | Glob: 6 copy-pasted implementations | Consolidated via shared `_matchPaths` | Phase 3 |
| H-6 | Fully-qualified module name collision | Resolved by deleting File.System.Create.File stub | Phase 1 |
| M-4 | File.Unsafe.Sendable unused | Deleted | Phase 1 |
| M-5 | Excessive re-exports (ASCII, RFC_4648) | Removed `@_exported` | Phase 1 |
| M-6 | Path.Component byte-level init duplication | Low priority, deferred | — |
| M-7 | Walk has three traversal implementations | Absorbed into C-5 | Phase 3 |
| M-11 | Duplicated error mapping (4→3) | Shared `_mapKernelError`, eliminated duplicate | Phase 3 |
| L-1 | 6 stub implementations | Deleted | Phase 1 |
| L-4 | FTS walker Darwin-only | Deleted | Phase 1 |

---

## Dependency Utilization Matrix (Current)

| Dependency | Module Used | Utilization | Assessment |
|------------|-------------|-------------|------------|
| **swift-kernel** | `Kernel` | **Heavy** | Core. Fully justified. |
| **swift-io** | `IO`, `IO Primitives` | **Moderate** | `IO.run` for async, `IO.Closable` now used by File.Descriptor. |
| **swift-paths** | `Paths` | **Heavy** | `File.Path = Paths.Path`. Core. `kernelPath` property. |
| **swift-strings** | `Strings` | **Light** | `String.strictUTF8()` in File.Name. Justified. |
| **swift-environment** | `Environment` | **Very light** | Single call site: `Environment.read("HOME")`. |
| **swift-ascii** | `ASCII` | **Marginal** | Verify necessity; may be transitive-only. |
| **swift-binary-primitives** | `Binary Primitives` | **Moderate** | `Binary.Serializable` conformances on 6 types. |
| **swift-rfc-4648** | `RFC 4648` | **Very light** | Hex encoding in File.Name debug only. |

---

## Statistics

| Metric | Pre-Audit | Post-Phase-1-2 | Post-Phase-3 |
|--------|-----------|----------------|--------------|
| Source files (FSP) | 59 | 47 | 47 |
| Source files (FS) | 33 | 31 | 32 |
| Total source files | 92 | 78 | 79 |
| Total source lines | ~11,400 | ~9,600 | ~9,300 |
| fatalError("unreachable") | 6 | 0 | 0 |
| Result<> workarounds | 8 | 0 | 0 |
| Kernel.Path.scope calls | 6 | 0 | 0 |
| catch let error as | 14 | 5 | 5 |
| Tests passing | 709 | 709 | 709 |

Note: FS file count went from 31→32 because `Glob.swift` gained the shared `_matchPaths` function (no new file; the count reflects the `+1` from the Glob file edit visibility in the build).
